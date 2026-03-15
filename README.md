# <h1 align="center"> Asseto Chainlink CCIP </h1>

**基于 Chainlink CCIP 的跨链代币转移项目**

![Github Actions](https://github.com/foundry-rs/forge-template/workflows/CI/badge.svg)

## 项目简介

本项目基于 [Chainlink CCIP (Cross-Chain Interoperability Protocol)](https://docs.chain.link/ccip) 实现 **Burn-and-Mint** 模式的跨链代币转移，支持在 **BSC** 和 **Ethereum** 主网之间安全地转移自定义 ERC20 代币。

### 核心合约

| 合约 | 说明 |
|------|------|
| `TokenTransferorPool` | 跨链代币转移池，继承 `BurnFromMintTokenPool`，负责跨链消息发送与代币 burn/mint |
| `Erc20Token` | 可升级 ERC20 代币（UUPS 代理模式），支持 CCIP Token Registry 自助注册 |

## 快速开始

### 前置要求

- [Foundry](https://getfoundry.sh) — Solidity 开发框架
- Git

### 安装依赖

```sh
git submodule update --init --recursive
```

### 配置环境变量

复制 `.env.example` 到 `.env` 并填写必要配置：

```sh
cp .env.example .env
```

需要配置以下内容：
- `PRIVATE_KEY` — 部署者私钥
- `ETHERSCAN_KEY` — Etherscan API Key（用于合约验证）
- RPC URL — BSC 和 Ethereum 的测试网/主网 RPC 地址

### 编译

```sh
forge build
```

### 测试

```sh
forge test
```

> **注意**: 跨链测试使用 Fork 模式，需要配置有效的 RPC URL。

## 部署流程

### 1. 部署 ERC20 代币

```sh
forge script script/token/DeployErc20Token.s.sol --broadcast
```

### 2. 部署 TokenTransferorPool

```sh
forge script script/DeployTokenTransferorPool.s.sol --broadcast
```

### 3. 配置跨链参数

包括：Token 注册到 CCIP Registry、Pool 配置远程链信息、设置速率限制等。

```sh
forge script script/UseTokenTransferorPool.s.sol --broadcast
```

## 项目结构

```
src/
├── TokenTransferorPool.sol          # 核心跨链转移合约
└── token/
    └── Erc20Token.sol               # 可升级 ERC20 代币合约

script/
├── DeployTokenTransferorPool.s.sol  # Pool 部署脚本（双链）
├── UseTokenTransferorPool.s.sol     # Pool 配置脚本（注册、链更新、转账）
└── token/
    ├── DeployErc20Token.s.sol       # 代币部署脚本
    └── UseErc20Token.s.sol          # 代币配置脚本

test/
├── TokenTransferorPool.t.sol        # 跨链转移 Fork 测试
└── token/
    └── Erc20Token.t.sol             # 代币基础功能测试
```

## 开发

本项目使用 [Foundry](https://getfoundry.sh) 开发框架，详见 [Foundry Book](https://book.getfoundry.sh/getting-started/installation.html) 了解安装和使用说明。

### 常用命令

```sh
forge build              # 编译合约
forge test               # 运行测试
forge test -vvvv         # 运行测试（详细日志输出）
forge fmt                # 格式化代码
forge snapshot           # 生成 Gas 快照
```

## 许可证

MIT
