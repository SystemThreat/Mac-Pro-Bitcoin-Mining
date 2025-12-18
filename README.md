

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ███╗   ███╗ █████╗  ██████╗███╗   ███╗███████╗████████╗ █████╗ ██╗          ║
║   ████╗ ████║██╔══██╗██╔════╝████╗ ████║██╔════╝╚══██╔══╝██╔══██╗██║          ║
║   ██╔████╔██║███████║██║     ██╔████╔██║█████╗     ██║   ███████║██║          ║
║   ██║╚██╔╝██║██╔══██║██║     ██║╚██╔╝██║██╔══╝     ██║   ██╔══██║██║          ║
║   ██║ ╚═╝ ██║██║  ██║╚██████╗██║ ╚═╝ ██║███████╗   ██║   ██║  ██║███████╗     ║
║   ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ║
║                                                                               ║
║                    ₿ Bitcoin Solo Mining for macOS 🍎                         ║
║                         Native Metal GPU Acceleration                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

# ₿ MacMetal Miner

<p align="center">
  <img src="screenshots/banner.png" alt="MacMetal Miner Banner" width="600">
</p>

<p align="center">
  <strong>The First Open-Source Native Metal GPU Bitcoin Miner for Apple Silicon</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#performance">Performance</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/GPU-Metal-orange?style=flat-square" alt="Metal">
  <img src="https://img.shields.io/badge/Chip-Apple%20Silicon-green?style=flat-square" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License">
</p>

---

## 🎰 What Is This?

MacMetal Miner is a **native Swift + Metal GPU Bitcoin solo miner** designed specifically for Apple Silicon Macs (M1/M2/M3/M4). It leverages Apple's Metal compute shaders to perform SHA256d hashing directly on the GPU, achieving hashrates previously thought impossible on macOS.

**⚠️ Important:** This is a *lottery miner*. Solo mining Bitcoin with consumer hardware is like buying a lottery ticket - the odds of finding a block are astronomically low, but if you win, you get the entire block reward (~3.125 BTC ≈ $270,000).

## ✨ Features

- 🎮 **Native Metal GPU Acceleration** - True GPU compute shaders, not CPU mining
- 🍎 **Built for Apple Silicon** - Optimized for M1/M2/M3/M4 chips
- ⚡ **High Performance** - 350+ MH/s on M3 Pro (352x faster than Python!)
- 🔗 **Stratum Protocol** - Connects to solo.ckpool.org and other pools
- 🎨 **Beautiful Terminal UI** - Real-time stats with color-coded display
- 🔊 **Sound Effects** - Audio notifications for shares and blocks
- 💾 **Persistent Stats** - Tracks cumulative shares across sessions
- 📖 **100% Open Source** - MIT Licensed, learn and modify freely

## 📊 Performance

| Mac Model | GPU Cores | Hashrate | Shares/Hour |
|-----------|-----------|----------|-------------|
| M3 Pro | 14 | **352 MH/s** | ~295 |
| M3 Max | 30 | ~600 MH/s* | ~500 |
| M2 Pro | 16 | ~280 MH/s* | ~230 |
| M1 Pro | 14 | ~200 MH/s* | ~165 |
| M1 | 8 | ~120 MH/s* | ~100 |

*Estimated based on GPU core count. Actual results may vary.

### Comparison

| Method | Hashrate | Improvement |
|--------|----------|-------------|
| Python (threading) | 1 MH/s | Baseline |
| **MacMetal Miner** | **352 MH/s** | **352x faster** |

## 🎲 Mining Odds

Let's be real about the math:

| Timeframe | Chance of Finding Block |
|-----------|------------------------|
| Per hour | 1 in 5.7 billion |
| Per day | 1 in 237 million |
| Per year | 1 in 650,000 |
| Per lifetime | 1 in 8,125 |

**But remember:** Someone with just 1 MH/s won a block worth $272,000 in December 2024. Every hash is a lottery ticket! 🎰

## 🚀 Installation

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4) or Intel Mac with Metal GPU
- Xcode Command Line Tools

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/macmetal-miner.git
cd macmetal-miner

# Build the miner
./build.sh

# Run with your Bitcoin address
./BTCMiner YOUR_BITCOIN_ADDRESS
```

### Manual Build

```bash
# Install Xcode Command Line Tools (if not installed)
xcode-select --install

# Compile
swiftc -O -o BTCMiner main.swift -framework Metal -framework Foundation -framework Network

# Run
./BTCMiner bc1qYourBitcoinAddressHere
```

## 📖 Usage

```bash
# Basic usage
./BTCMiner <BITCOIN_ADDRESS>

# Example with real address
./BTCMiner bc1q2xh89ghtpxya8hj34vulfvx3ckl6rf00umayjt
```

### Controls

- `Ctrl+C` - Stop mining and show session summary

### Output Explained

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ₿ BITCOIN LOTTERY v7.3  🎮 METAL GPU  ● LIVE  ⚡ 352.07 MH/s
  💰 $86,421    🪙 1157 sats/$1    🎰 Jackpot: $270,000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎯 Best Diff: 34    💸 Cost: $0.0007    ⏱️ Uptime: 0:05:00
```

| Field | Meaning |
|-------|---------|
| ⚡ Hashrate | Current hashing speed |
| 🎯 Best Diff | Highest difficulty hash found (Bitcoin needs 76+) |
| 💸 Cost | Estimated electricity cost |
| Session/Total | Shares found this session / all time |

## 🔧 How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MacMetal Miner                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Stratum   │  │    Swift    │  │    Metal Shader     │ │
│  │   Client    │◄─┤    Host     │◄─┤   (SHA256d GPU)     │ │
│  │  (Network)  │  │  (Control)  │  │  (16M hashes/batch) │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              solo.ckpool.org:3333                    │   │
│  │                 (Mining Pool)                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### The Mining Process

1. **Connect** to solo mining pool via Stratum protocol
2. **Receive** block template (previous hash, merkle branches, etc.)
3. **Build** 80-byte block header
4. **Dispatch** 16 million nonces to GPU in parallel
5. **Compute** double SHA256 on each header variation
6. **Check** if hash meets difficulty target
7. **Submit** valid shares to pool
8. **Repeat** with new nonces

### Metal Compute Shader

The GPU kernel (`SHA256.metal`) implements:
- Full SHA256 compression function
- Double SHA256 (SHA256d) for Bitcoin
- Parallel processing of millions of nonces
- Atomic counters for hash counting
- Share detection (32+ zero bits)

## 📁 Project Structure

```
macmetal-miner/
├── README.md           # This file
├── LICENSE             # MIT License
├── build.sh            # Build script
├── main.swift          # Swift host application
├── SHA256.metal        # Metal compute shader
├── docs/
│   ├── TECHNICAL.md    # Technical deep-dive
│   └── STRATUM.md      # Stratum protocol docs
└── screenshots/
    └── demo.png        # Screenshot
```

## 🎓 Educational Value

This project demonstrates:

- **Metal Compute Shaders** - GPU programming on Apple platforms
- **SHA256 Implementation** - Cryptographic hashing from scratch
- **Stratum Protocol** - Bitcoin mining pool communication
- **Swift Networking** - Native Network.framework usage
- **Concurrent Programming** - Managing GPU workloads

## ⚠️ Disclaimers

- **Not Financial Advice** - Solo mining is a lottery, not an investment
- **Electricity Costs** - Mining uses power; calculate your costs
- **Hardware Wear** - Extended GPU usage may increase wear
- **No Guarantees** - You may never find a block

## 🤝 Contributing

Contributions are welcome! Ideas for improvement:

- [ ] Multiple pool failover support
- [ ] Testnet support
- [ ] Menu bar app version (SwiftUI)
- [ ] Performance optimizations
- [ ] Block submission handling
- [ ] Intel Mac optimization

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- **Satoshi Nakamoto** - For creating Bitcoin
- **CKPool** - For providing solo mining infrastructure
- **Apple** - For Metal compute framework
- **The Bitcoin Community** - For keeping the dream alive

## 📈 Stats

If you find a block using this miner, please let us know! 🎉

---

<p align="center">
  <strong>Built with ❤️ and Metal on macOS</strong>
</p>

<p align="center">
  <em>"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"</em>
</p>

<p align="center">
  ₿ HODL! 💎🙌
</p>
