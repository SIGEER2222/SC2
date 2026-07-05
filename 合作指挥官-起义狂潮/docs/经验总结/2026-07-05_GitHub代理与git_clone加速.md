# GitHub 代理与 git clone 加速

## 场景

在国内克隆 GitHub 大仓库（如 SC2Mapster/SC2GameData，18458 个对象，1.5GB+ 解压后）速度极慢。

## 关键发现

### 1. TUN 模式下"直连"反而最快

TUN 模式是透明代理，所有流量自动走代理，**不需要**为 git 单独配置 `http.proxy`。
显式配置 `http.proxy` 反而会形成"双重代理"，速度更慢：

| 测试方式 | 耗时 |
|---------|------|
| 直连（流量走 TUN） | 1544ms |
| 显式走代理 7897 | 2674ms |

### 2. git clone 慢 ≠ 网络慢

实测同一个仓库：

| 方式 | 速度 |
|------|------|
| `git clone --depth=1` | 30-50 KiB/s |
| 直接下载 zip 包（codeload） | **5.92 MB/s** |

**150 倍差距**。原因是 git smart HTTP 协议需要为 18458 个对象分别发起 HTTP 请求，
TUN 代理对这种密集小请求处理很差。而 codeload.github.com 的 zip 下载是单一大文件 HTTP 流，
代理处理良好。

### 3. 常见 GitHub 镜像大多失效或被代理拦

- `kkgithub.com`：仓库不全，部分仓库 404
- `ghfast.top`：返回 403 FORBIDDEN
- `mirror.ghproxy.com` / `ghps.cc`：SSL 握手失败

## 推荐方案

### 对于大仓库（>10MB）：用 zip 包代替 git clone

```powershell
# 1. 下载 zip 包
$targetDir = "E:\path\to\RepoName"
$zipFile = "$targetDir.zip"
Invoke-WebRequest -Uri "https://codeload.github.com/USER/REPO/zip/refs/heads/master" -OutFile $zipFile

# 2. 解压
Expand-Archive -Path $zipFile -DestinationPath "E:\path\to\_tmp" -Force
Move-Item "E:\path\to\_tmp\REPO-master" $targetDir -Force

# 3. 清理
Remove-Item "E:\path\to\_tmp" -Recurse -Force
Remove-Item $zipFile -Force

# 4.（可选）初始化为 git 仓库并添加 remote，保留后续 fetch 能力
cd $targetDir
git init -q
git add -A
git commit -q -m "拉取快照"
git remote add origin https://github.com/USER/REPO.git
git branch -M master
```

### 对于小仓库（<10MB）：直接 git clone

TUN 模式下小仓库速度可接受。

### git 传输参数优化（可选）

```powershell
git config --global http.postBuffer 524288000  # 500MB
git config --global http.version HTTP/2
git config --global core.compression 0
```

## 关于代理端口

- Clash Verge / Mihomo 默认 HTTP 代理端口是 **7897**（不是 7890）
- 监听端口可以用 `Get-NetTCPConnection -State Listen` 查询
- TUN 模式开启后，应用层面无需配置代理

## 总结

| 情况 | 建议 |
|------|------|
| 小仓库，已开 TUN | 直接 git clone |
| 大仓库（>10MB），已开 TUN | 用 codeload zip 下载 + 解压 + git init |
| 必须要 git 历史 | 切换更快的代理节点；或 zip 拉取后 `git fetch --unshallow` |

## 本次任务实测数据

- 仓库：SC2Mapster/SC2GameData
- 大小：111.24 MB（zip）/ 1567.29 MB（解压后）
- zip 下载：18.78 秒（5.92 MB/s）
- git clone 尝试：3 分钟仅 2% 进度，预计 3+ 小时
- 镜像方案：kkgithub 404，ghfast.top 403，ghproxy SSL 失败
