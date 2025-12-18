//
//  main.swift
//  MacMetal Miner
//
//  Native Swift + Metal GPU Bitcoin Solo Miner for Apple Silicon
//  Connects to solo.ckpool.org via Stratum protocol
//
//  MIT License - See LICENSE for details
//

import Foundation
import Metal
import Network
import CommonCrypto

// ============================================================================
// MARK: - ANSI Terminal Colors
// ============================================================================

struct Colors {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    // Standard colors
    static let red = "\u{001B}[91m"
    static let green = "\u{001B}[92m"
    static let yellow = "\u{001B}[93m"
    static let blue = "\u{001B}[94m"
    static let magenta = "\u{001B}[95m"
    static let cyan = "\u{001B}[96m"
    
    // 256-color palette
    static let gold = "\u{001B}[38;5;220m"
    static let pink = "\u{001B}[38;5;198m"
    static let lime = "\u{001B}[38;5;118m"
    static let aqua = "\u{001B}[38;5;45m"
    static let orange = "\u{001B}[38;5;208m"
    static let violet = "\u{001B}[38;5;135m"
    
    // Terminal control
    static let clearScreen = "\u{001B}[2J"
    static let home = "\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
}

// ============================================================================
// MARK: - Mining Result Structure
// ============================================================================

/// Matches the Metal shader's MiningResult struct
struct MiningResult {
    var nonce: UInt32
    var hash: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
    var zeros: UInt32
}

// ============================================================================
// MARK: - Stratum Job
// ============================================================================

/// Represents a mining job received from the pool
struct StratumJob {
    var id: String
    var prevHash: String
    var coinbase1: String
    var coinbase2: String
    var merkleBranches: [String]
    var version: String
    var nbits: String
    var ntime: String
    var cleanJobs: Bool
}

// ============================================================================
// MARK: - GPU Miner
// ============================================================================

/// Metal GPU miner - handles all GPU communication
class GPUMiner {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    
    /// Number of hashes per GPU dispatch (16 million)
    let batchSize: Int = 1024 * 1024 * 16
    
    // Metal buffers
    var headerBuffer: MTLBuffer?
    var nonceBuffer: MTLBuffer?
    var hashCountBuffer: MTLBuffer?
    var resultCountBuffer: MTLBuffer?
    var resultsBuffer: MTLBuffer?
    var targetBuffer: MTLBuffer?
    
    /// Initialize the GPU miner
    init?() {
        // Get the default Metal device (GPU)
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("\(Colors.red)❌ Metal not supported on this device\(Colors.reset)")
            return nil
        }
        self.device = device
        
        // Create command queue
        guard let queue = device.makeCommandQueue() else {
            print("\(Colors.red)❌ Could not create Metal command queue\(Colors.reset)")
            return nil
        }
        self.commandQueue = queue
        
        // Load and compile the Metal shader
        let shaderPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SHA256.metal")
        
        guard let shaderSource = try? String(contentsOf: shaderPath) else {
            print("\(Colors.red)❌ Could not load SHA256.metal shader file\(Colors.reset)")
            print("\(Colors.dim)   Make sure SHA256.metal is in the current directory\(Colors.reset)")
            return nil
        }
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let function = library.makeFunction(name: "mine") else {
                print("\(Colors.red)❌ Could not find 'mine' function in shader\(Colors.reset)")
                return nil
            }
            self.pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            print("\(Colors.red)❌ Shader compilation error: \(error)\(Colors.reset)")
            return nil
        }
        
        // Allocate Metal buffers
        headerBuffer = device.makeBuffer(length: 76, options: .storageModeShared)
        nonceBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        hashCountBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        resultCountBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        resultsBuffer = device.makeBuffer(length: MemoryLayout<MiningResult>.size * 100, options: .storageModeShared)
        targetBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        
        print("\(Colors.green)✅ GPU Initialized: \(device.name)\(Colors.reset)")
        print("\(Colors.cyan)   Max threads/threadgroup: \(pipeline.maxTotalThreadsPerThreadgroup)\(Colors.reset)")
        print("\(Colors.cyan)   Batch size: \(batchSize.formatted()) hashes/dispatch\(Colors.reset)")
    }
    
    /// Mine a batch of nonces on the GPU
    /// - Parameters:
    ///   - header: 76-byte block header (without nonce)
    ///   - nonceStart: Starting nonce value
    ///   - targetZeros: Minimum zero bits for a share (default 32)
    /// - Returns: Tuple of (total hashes computed, array of (nonce, zeros) for shares found)
    func mine(header: [UInt8], nonceStart: UInt32, targetZeros: UInt32 = 32) -> (hashes: UInt64, results: [(UInt32, UInt32)]) {
        guard header.count == 76 else {
            print("\(Colors.red)❌ Invalid header length: \(header.count) (expected 76)\(Colors.reset)")
            return (0, [])
        }
        
        // Copy header to GPU buffer
        memcpy(headerBuffer!.contents(), header, 76)
        
        // Set starting nonce
        var nonce = nonceStart
        memcpy(nonceBuffer!.contents(), &nonce, 4)
        
        // Reset counters
        memset(hashCountBuffer!.contents(), 0, 4)
        memset(resultCountBuffer!.contents(), 0, 4)
        
        // Set target difficulty
        var target = targetZeros
        memcpy(targetBuffer!.contents(), &target, 4)
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return (0, [])
        }
        
        // Set up the compute pipeline
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(headerBuffer, offset: 0, index: 0)
        encoder.setBuffer(nonceBuffer, offset: 0, index: 1)
        encoder.setBuffer(hashCountBuffer, offset: 0, index: 2)
        encoder.setBuffer(resultCountBuffer, offset: 0, index: 3)
        encoder.setBuffer(resultsBuffer, offset: 0, index: 4)
        encoder.setBuffer(targetBuffer, offset: 0, index: 5)
        
        // Calculate thread dispatch sizes
        let threadsPerGroup = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
        let threadGroups = (batchSize + threadsPerGroup - 1) / threadsPerGroup
        
        // Dispatch threads to GPU
        encoder.dispatchThreadgroups(
            MTLSize(width: threadGroups, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        )
        
        encoder.endEncoding()
        
        // Execute and wait for completion
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read results from GPU
        let hashCount = hashCountBuffer!.contents().load(as: UInt32.self)
        let resultCount = resultCountBuffer!.contents().load(as: UInt32.self)
        
        var shares: [(UInt32, UInt32)] = []
        if resultCount > 0 {
            let resultsPtr = resultsBuffer!.contents().bindMemory(to: MiningResult.self, capacity: 100)
            for i in 0..<min(Int(resultCount), 100) {
                let result = resultsPtr[i]
                shares.append((result.nonce, result.zeros))
            }
        }
        
        return (UInt64(hashCount), shares)
    }
}

// ============================================================================
// MARK: - Stratum Client
// ============================================================================

/// Handles communication with the mining pool via Stratum protocol
class StratumClient {
    var socket: NWConnection?
    var extranonce1: String = ""
    var extranonce2Size: Int = 4
    var currentJob: StratumJob?
    var address: String
    var isConnected = false
    
    // Callbacks
    var onJobReceived: ((StratumJob) -> Void)?
    var onConnected: (() -> Void)?
    
    init(address: String) {
        self.address = address
    }
    
    /// Connect to the mining pool
    func connect() {
        let host = NWEndpoint.Host("solo.ckpool.org")
        let port = NWEndpoint.Port(rawValue: 3333)!
        
        socket = NWConnection(host: host, port: port, using: .tcp)
        
        socket?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.subscribe()
            case .failed(let error):
                print("\(Colors.red)❌ Connection failed: \(error)\(Colors.reset)")
                self?.isConnected = false
            default:
                break
            }
        }
        
        socket?.start(queue: .global())
        receiveData()
    }
    
    /// Subscribe to mining notifications
    private func subscribe() {
        let msg = "{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"MacMetalMiner/1.0\"]}\n"
        send(msg)
    }
    
    /// Authorize the worker
    func authorize() {
        let msg = "{\"id\":2,\"method\":\"mining.authorize\",\"params\":[\"\(address).metal\",\"x\"]}\n"
        send(msg)
    }
    
    /// Send a message to the pool
    private func send(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        socket?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("\(Colors.red)❌ Send error: \(error)\(Colors.reset)")
            }
        })
    }
    
    /// Receive data from the pool
    private func receiveData() {
        socket?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let data = content, let str = String(data: data, encoding: .utf8) {
                self?.handleMessage(str)
            }
            if !isComplete {
                self?.receiveData()
            }
        }
    }
    
    /// Handle incoming messages from the pool
    private func handleMessage(_ message: String) {
        for line in message.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            // Handle subscription response
            if let result = json["result"] as? [Any], result.count >= 2 {
                if let details = result[0] as? [[Any]], !details.isEmpty {
                    extranonce1 = result[1] as? String ?? ""
                    extranonce2Size = result[2] as? Int ?? 4
                    authorize()
                }
            }
            
            // Handle job notification
            if let method = json["method"] as? String, method == "mining.notify",
               let params = json["params"] as? [Any], params.count >= 9 {
                let job = StratumJob(
                    id: params[0] as? String ?? "",
                    prevHash: params[1] as? String ?? "",
                    coinbase1: params[2] as? String ?? "",
                    coinbase2: params[3] as? String ?? "",
                    merkleBranches: params[4] as? [String] ?? [],
                    version: params[5] as? String ?? "",
                    nbits: params[6] as? String ?? "",
                    ntime: params[7] as? String ?? "",
                    cleanJobs: params[8] as? Bool ?? false
                )
                currentJob = job
                onJobReceived?(job)
            }
            
            // Handle authorization response
            if let id = json["id"] as? Int, id == 2, let result = json["result"] as? Bool, result {
                onConnected?()
            }
        }
    }
}

// ============================================================================
// MARK: - Helper Functions
// ============================================================================

/// Convert hex string to byte array
func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
            bytes.append(byte)
        }
        index = nextIndex
    }
    return bytes
}

/// Double SHA256 hash
func sha256d(_ data: [UInt8]) -> [UInt8] {
    var digest1 = [UInt8](repeating: 0, count: 32)
    var digest2 = [UInt8](repeating: 0, count: 32)
    
    _ = data.withUnsafeBytes { ptr in
        CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &digest1)
    }
    _ = digest1.withUnsafeBytes { ptr in
        CC_SHA256(ptr.baseAddress, CC_LONG(32), &digest2)
    }
    
    return digest2
}

/// Build the block header from a Stratum job
func buildHeader(job: StratumJob, extranonce1: String, extranonce2: String) -> [UInt8] {
    // Build coinbase transaction
    let coinbaseHex = job.coinbase1 + extranonce1 + extranonce2 + job.coinbase2
    let coinbase = hexToBytes(coinbaseHex)
    
    // Calculate merkle root
    var merkle = sha256d(coinbase)
    for branch in job.merkleBranches {
        merkle = sha256d(merkle + hexToBytes(branch))
    }
    
    // Build 76-byte header (without nonce)
    var header: [UInt8] = []
    
    // Version (4 bytes, little-endian)
    let version = UInt32(job.version, radix: 16) ?? 0
    header += withUnsafeBytes(of: version.littleEndian) { Array($0) }
    
    // Previous block hash (32 bytes, reversed)
    let prevHash = hexToBytes(job.prevHash)
    header += prevHash.reversed()
    
    // Merkle root (32 bytes, reversed)
    header += merkle.reversed()
    
    // Timestamp (4 bytes, little-endian)
    let ntime = UInt32(job.ntime, radix: 16) ?? 0
    header += withUnsafeBytes(of: ntime.littleEndian) { Array($0) }
    
    // Bits/difficulty target (4 bytes, little-endian)
    let nbits = hexToBytes(job.nbits)
    header += nbits.reversed()
    
    return header
}

/// Play a sound effect
func playSound(_ type: String) {
    let sounds: [String: String] = [
        "share": "/System/Library/Sounds/Glass.aiff",
        "block": "/System/Library/Sounds/Blow.aiff",
        "connect": "/System/Library/Sounds/Funk.aiff",
        "start": "/System/Library/Sounds/Purr.aiff"
    ]
    if let path = sounds[type] {
        Process.launchedProcess(launchPath: "/usr/bin/afplay", arguments: ["-v", "1", path])
    }
}

/// Format a number with commas
extension UInt64 {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// ============================================================================
// MARK: - Bitcoin Miner
// ============================================================================

/// Main miner class - coordinates GPU, network, and UI
class BitcoinMiner {
    let gpu: GPUMiner
    let stratum: StratumClient
    let address: String
    
    // Statistics
    var totalHashes: UInt64 = 0
    var sessionShares: Int = 0
    var allTimeShares: Int = 0
    var bestDiff: UInt32 = 0
    var startTime: Date
    var lastShareTime: Date?
    var btcPrice: Double = 0
    var blockHeight: Int = 0
    var blockTime: Date = Date()
    var isRunning = true
    var currentNonce: UInt32 = 0
    
    // Satoshi quotes
    let quotes = [
        "The Times 03/Jan/2009 Chancellor on brink of second bailout",
        "If you don't believe it or don't get it, I don't have time to convince you",
        "One CPU one vote",
        "Be your own bank",
        "Not your keys, not your coins",
        "HODL!",
        "Stay humble, stack sats",
        "Running bitcoin - Hal Finney"
    ]
    
    /// Initialize the miner
    init?(address: String) {
        guard let gpu = GPUMiner() else { return nil }
        self.gpu = gpu
        self.address = address
        self.stratum = StratumClient(address: address)
        self.startTime = Date()
        self.allTimeShares = loadShares()
        
        setupStratum()
    }
    
    /// Load cumulative shares from disk
    func loadShares() -> Int {
        let path = NSString(string: "~/.macmetal_shares.json").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = json["total"] as? Int else {
            return 0
        }
        return total
    }
    
    /// Save cumulative shares to disk
    func saveShares() {
        let path = NSString(string: "~/.macmetal_shares.json").expandingTildeInPath
        let json: [String: Any] = [
            "total": allTimeShares,
            "updated": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    /// Set up Stratum callbacks
    func setupStratum() {
        stratum.onConnected = { [weak self] in
            self?.log("🔑", Colors.green, "Authorized!")
            self?.fetchPrice()
        }
        
        stratum.onJobReceived = { [weak self] job in
            if job.cleanJobs {
                self?.blockTime = Date()
                self?.log("🧱", Colors.orange, "NEW BLOCK!")
                playSound("block")
            }
        }
    }
    
    /// Log a message
    func log(_ icon: String, _ color: String, _ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: Date())
        print("\(Colors.dim)\(time)\(Colors.reset)  \(icon)  \(color)\(message)\(Colors.reset)")
    }
    
    /// Fetch current BTC price
    func fetchPrice() {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let amount = dataObj["amount"] as? String,
               let price = Double(amount) {
                self?.btcPrice = price
            }
        }.resume()
    }
    
    /// Main entry point
    func run() {
        // Hide cursor and start
        print(Colors.hideCursor)
        print("\n\(Colors.gold)  ₿ MacMetal Miner - Bitcoin Solo Mining for macOS ⛏️\(Colors.reset)\n")
        
        playSound("start")
        
        log("🌐", Colors.blue, "Connecting to solo.ckpool.org:3333...")
        stratum.connect()
        
        // Wait for connection
        while !stratum.isConnected {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        log("✅", Colors.green, "Connected!")
        playSound("connect")
        
        // Start mining on background thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.miningLoop()
        }
        
        // UI loop on main thread
        while isRunning {
            updateUI()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
    
    /// Main mining loop
    func miningLoop() {
        while isRunning {
            guard let job = stratum.currentJob else {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }
            
            // Generate random extranonce2
            let extranonce2 = String(format: "%0\(stratum.extranonce2Size * 2)x", arc4random())
            
            // Build block header
            let header = buildHeader(job: job, extranonce1: stratum.extranonce1, extranonce2: extranonce2)
            
            guard header.count == 76 else { continue }
            
            // Mine batch on GPU
            let (hashes, results) = gpu.mine(header: header, nonceStart: currentNonce, targetZeros: 32)
            
            totalHashes += hashes
            currentNonce = currentNonce &+ UInt32(gpu.batchSize)
            
            // Process results
            for (nonce, zeros) in results {
                if zeros > bestDiff {
                    bestDiff = zeros
                }
                
                if zeros >= 32 {
                    sessionShares += 1
                    allTimeShares += 1
                    lastShareTime = Date()
                    saveShares()
                    log("💰", Colors.gold, "SHARE FOUND! Difficulty: \(zeros) bits 🎉")
                    playSound("share")
                }
            }
        }
    }
    
    /// Update terminal UI
    func updateUI() {
        let elapsed = Date().timeIntervalSince(startTime)
        let hashrate = Double(totalHashes) / max(elapsed, 1)
        
        // Format hashrate
        let hrStr: String
        let hrColor: String
        if hashrate > 1_000_000_000 {
            hrStr = String(format: "%.2f GH/s", hashrate / 1_000_000_000)
            hrColor = Colors.pink
        } else if hashrate > 1_000_000 {
            hrStr = String(format: "%.2f MH/s", hashrate / 1_000_000)
            hrColor = Colors.gold
        } else if hashrate > 1000 {
            hrStr = String(format: "%.1f KH/s", hashrate / 1000)
            hrColor = Colors.lime
        } else {
            hrStr = String(format: "%.0f H/s", hashrate)
            hrColor = Colors.cyan
        }
        
        // Calculate stats
        let jackpot = 3.125 * max(btcPrice, 100000)
        let satsPerDollar = 100_000_000 / max(btcPrice, 1)
        let odds = hashrate / 800_000_000_000_000_000
        let oddsStr = odds > 0 ? String(format: "1 in %.0f", 1/odds) : "--"
        
        let blockElapsed = Int(Date().timeIntervalSince(blockTime))
        let blockMin = blockElapsed / 60
        let blockSec = blockElapsed % 60
        
        let lastShareStr: String
        if let lastShare = lastShareTime {
            let since = Int(Date().timeIntervalSince(lastShare))
            lastShareStr = "\(since / 60)m\(String(format: "%02d", since % 60))s"
        } else {
            lastShareStr = "--"
        }
        
        let quoteIndex = Int(elapsed) / 30 % quotes.count
        let quote = quotes[quoteIndex]
        
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        let uptime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        
        let elecCost = (120.0 / 1000.0) * (elapsed / 3600.0) * 0.21
        
        // Build output
        var output = ""
        output += "\(Colors.home)\(Colors.clearScreen)"
        output += "\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)\n"
        output += "  \(Colors.bold)\(Colors.gold)₿ MacMetal Miner v1.0\(Colors.reset)  \(Colors.pink)🎮 METAL GPU\(Colors.reset)  \(Colors.lime)● LIVE\(Colors.reset)  \(hrColor)⚡ \(hrStr)\(Colors.reset)  \(Colors.aqua)🧱 Block\(Colors.reset)\n"
        output += "  \(Colors.gold)💰 $\(String(format: "%.2f", btcPrice))\(Colors.reset)    \(Colors.lime)🪙 \(Int(satsPerDollar)) sats/$1\(Colors.reset)    \(Colors.pink)🎰 Jackpot: $\(String(format: "%.0f", jackpot))\(Colors.reset)    \(Colors.dim)🎲 Odds: \(oddsStr)\(Colors.reset)\n"
        output += "\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)\n"
        
        output += "  \(Colors.dim)🎯 Best Diff:\(Colors.reset) \(Colors.lime)\(bestDiff)\(Colors.reset)    \(Colors.dim)💸 Cost:\(Colors.reset) \(Colors.red)$\(String(format: "%.4f", elecCost))\(Colors.reset)    \(Colors.dim)⏱️ Uptime:\(Colors.reset) \(Colors.aqua)\(uptime)\(Colors.reset)\n"
        output += "  \(Colors.dim)💬 \"\(quote)\"\(Colors.reset)\n\n"
        
        output += "\(Colors.magenta)── ⚡ HASHRATE & SHARES ──────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.gold)Speed:\(Colors.reset) \(hrColor)\(hrStr)\(Colors.reset)    \(Colors.gold)Hashes:\(Colors.reset) \(Colors.yellow)\(totalHashes.formatted())\(Colors.reset)    \(Colors.gold)Session:\(Colors.reset) \(Colors.lime)\(sessionShares)\(Colors.reset)    \(Colors.gold)Total:\(Colors.reset) \(Colors.pink)\(allTimeShares)\(Colors.reset)    \(Colors.gold)Last:\(Colors.reset) \(Colors.cyan)\(lastShareStr)\(Colors.reset)\n\n"
        
        output += "\(Colors.violet)── ⏱️ BLOCK ─────────────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  ⏱️ \(String(format: "%02d:%02d", blockMin, blockSec)) since block\n\n"
        
        output += "\(Colors.pink)── 🎮 GPU STATUS ────────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.lime)✅ Metal GPU Active\(Colors.reset)    \(Colors.dim)Device:\(Colors.reset) \(Colors.aqua)\(gpu.device.name)\(Colors.reset)    \(Colors.dim)Batch:\(Colors.reset) \(Colors.yellow)\(gpu.batchSize.formatted())\(Colors.reset)\n\n"
        
        output += "  \(Colors.dim)₿ \(address)    ⌨️ Ctrl+C to exit\(Colors.reset)\n"
        
        print(output)
    }
}

// ============================================================================
// MARK: - Main Entry Point
// ============================================================================

// Parse command line arguments
let args = CommandLine.arguments
guard args.count >= 2 else {
    print("""
    \(Colors.gold)₿ MacMetal Miner - Bitcoin Solo Mining for macOS\(Colors.reset)
    
    \(Colors.bold)Usage:\(Colors.reset) ./BTCMiner <BITCOIN_ADDRESS>
    
    \(Colors.bold)Example:\(Colors.reset)
      ./BTCMiner bc1qYourBitcoinAddressHere
    
    \(Colors.bold)Requirements:\(Colors.reset)
      - macOS 14.0 or later
      - Apple Silicon Mac (M1/M2/M3/M4) or Intel with Metal GPU
      - SHA256.metal shader file in current directory
    
    \(Colors.dim)This is a solo miner - you only win if you find a block.
    Current block reward: ~3.125 BTC (~$270,000)\(Colors.reset)
    """)
    exit(1)
}

let address = args[1]

print("\(Colors.gold)₿ MacMetal Miner v1.0 - Native Metal GPU Bitcoin Miner\(Colors.reset)")
print("\(Colors.dim)  The first open-source Metal GPU Bitcoin miner for Apple Silicon\(Colors.reset)\n")

// Initialize miner
guard let miner = BitcoinMiner(address: address) else {
    print("\(Colors.red)❌ Failed to initialize miner\(Colors.reset)")
    exit(1)
}

// Handle Ctrl+C gracefully
signal(SIGINT) { _ in
    print("\n\(Colors.showCursor)")
    print("\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)")
    print("  \(Colors.bold)SESSION COMPLETE 🏁\(Colors.reset)")
    print("\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)")
    print("  \(Colors.pink)🎰 Thanks for mining! HODL! 💎🙌\(Colors.reset)\n")
    exit(0)
}

// Start mining!
miner.run()
