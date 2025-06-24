#!/bin/bash

# TiDB单机模拟部署脚本
# 功能：在单台Linux服务器上部署最小拓扑的TiDB集群
# 支持系统：EulerOS 2.0 (ARM/x86) 和 Ubuntu 24.04 (ARM/x86)

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root用户运行此脚本"
  exit 1
fi

# 检测系统类型和架构
detect_system() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
  elif [ -f /etc/hce-release ]; then
    OS="hce"
    OS_VERSION=$(grep -oP '(?<=release )\d' /etc/hce-release)
  else
    echo "无法识别的操作系统"
    exit 1
  fi

  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) 
      echo "不支持的架构: $ARCH"
      exit 1
      ;;
  esac

  echo "检测到系统: $OS $OS_VERSION $ARCH"
}

# 自动获取局域网IP
get_local_ip() {
  local ip
  # 尝试多种方法获取IP
  ip=$(ip route get 1 | awk '{print $7}' | head -1 2>/dev/null)
  if [ -z "$ip" ]; then
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
  fi
  if [ -z "$ip" ]; then
    ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
  fi
  
  if [ -z "$ip" ]; then
    echo "无法自动获取IP地址，请手动设置"
    exit 1
  fi
  
  echo "$ip"
}

# 验证命令是否存在
command_exists() {
  command -v "$@" >/dev/null 2>&1
}

# 安装TiUP
install_tiup() {
  if command_exists tiup; then
    echo "TiUP已经安装"
    return 0
  fi

  echo "正在安装TiUP..."
  curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
  
  # 确保tiup在PATH中
  export PATH=$PATH:$HOME/.tiup/bin
  
  # 根据系统类型source不同的文件
  if [ "$OS" = "ubuntu" ]; then
    source ${HOME}/.bashrc
  else
    [ -f "${HOME}/.bash_profile" ] && source ${HOME}/.bash_profile
  fi

  # 再次验证tiup是否可用
  if ! command_exists tiup; then
    echo "TiUP安装失败，请手动检查"
    exit 1
  fi

  echo "TiUP安装成功"
}

# 安装cluster组件
install_cluster_component() {
  echo "正在安装TiUP cluster组件..."
  tiup --binary cluster || true  # 忽略第一次运行的错误
  tiup update --self && tiup update cluster
}

# 调整sshd配置
adjust_sshd_config() {
  echo "调整sshd配置..."
  if grep -q "^#MaxSessions 10" /etc/ssh/sshd_config; then
    sed -i 's/^#MaxSessions 10/MaxSessions 20/' /etc/ssh/sshd_config
  elif grep -q "^MaxSessions 10" /etc/ssh/sshd_config; then
    sed -i 's/^MaxSessions 10/MaxSessions 20/' /etc/ssh/sshd_config
  else
    echo "MaxSessions 20" >> /etc/ssh/sshd_config
  fi
  systemctl restart sshd
}

# 创建拓扑文件
create_topology_file() {
  local ip=$1
  echo "创建拓扑配置文件topo.yaml..."
  cat > topo.yaml <<EOF
# Global variables are applied to all deployments and used as the default value of
# the deployments if a specific deployment value is missing.
global:
 user: "tidb"
 ssh_port: 22
 deploy_dir: "/tidb-deploy"
 data_dir: "/tidb-data"

# Monitored variables are applied to all the machines.
monitored:
 node_exporter_port: 9100
 blackbox_exporter_port: 9115

server_configs:
 tidb:
   instance.tidb_slow_log_threshold: 300
 tikv:
   readpool.storage.use-unified-pool: false
   readpool.coprocessor.use-unified-pool: true
 pd:
   replication.enable-placement-rules: true
   replication.location-labels: ["host"]
 tiflash:
   logger.level: "info"

pd_servers:
 - host: $ip

tidb_servers:
 - host: $ip

tikv_servers:
 - host: $ip
   port: 20160
   status_port: 20180
   config:
     server.labels: { host: "logic-host-1" }

 - host: $ip
   port: 20161
   status_port: 20181
   config:
     server.labels: { host: "logic-host-2" }

 - host: $ip
   port: 20162
   status_port: 20182
   config:
     server.labels: { host: "logic-host-3" }

tiflash_servers:
 - host: $ip

monitoring_servers:
 - host: $ip

grafana_servers:
 - host: $ip
EOF
}

# 部署集群
deploy_cluster() {
  local ip=$1
  local cluster_name=$2
  local version=$3

  echo "正在部署TiDB集群..."

  create_topology_file $ip

  tiup cluster deploy $cluster_name $version ./topo.yaml --user root -p
}

# 启动集群
start_cluster() {
  local cluster_name=$1
  echo "启动TiDB集群..."
  tiup cluster start $cluster_name
  sleep 5
}

# 安装MySQL客户端
install_mysql_client() {
  echo "安装MySQL客户端..."
  if [ "$OS" = "ubuntu" ]; then
    apt-get update
    apt-get -y install mysql-client
  else
    yum -y install mysql
  fi
}

# 创建系统服务
create_systemd_service() {
  local cluster_name=$1
  local service_file="/etc/systemd/system/tidb-${cluster_name}.service"
  
  echo "创建系统服务: tidb-${cluster_name}.service"
  
  # 获取tiup的完整路径
  local tiup_path=$(command -v tiup)
  if [ -z "$tiup_path" ]; then
    echo "无法找到tiup路径，跳过创建系统服务"
    return 1
  fi

  cat > $service_file <<EOF
[Unit]
Description=TiDB Cluster ${cluster_name}
After=network.target

[Service]
Type=forking
User=root
ExecStart=${tiup_path} cluster start ${cluster_name}
ExecStop=${tiup_path} cluster stop ${cluster_name}
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable tidb-${cluster_name}.service
  
  # 不立即启动服务，因为集群可能已经启动
  echo "系统服务已创建但未启动（集群已手动启动）"
}

# 显示集群信息
show_cluster_info() {
  local cluster_name=$1
  echo "集群列表:"
  tiup cluster list
  echo "集群拓扑和状态:"
  tiup cluster display $cluster_name
}

# 主函数
main() {
  detect_system
  
  local ip="127.0.0.1"
  local cluster_name="tidb-test-cluster"
  local version="v8.5.1"  # 可以修改为需要的版本

  echo "===== TiDB单机模拟部署开始 ====="
  echo "使用IP地址: $ip"
  echo "集群名称: $cluster_name"
  echo "TiDB版本: $version"

  # 执行部署步骤
  install_tiup
  install_cluster_component
  adjust_sshd_config
  deploy_cluster $ip $cluster_name $version
  start_cluster $cluster_name
  install_mysql_client
  create_systemd_service $cluster_name

  # 显示部署结果
  echo "===== 部署完成 ====="
  echo "1. 使用MySQL客户端连接TiDB:"
  echo "   mysql -h $ip -P 4000 -u root"
  echo "2. 访问Grafana监控: http://$ip:3000 (用户名/密码: admin/admin)"
  echo "3. 访问TiDB Dashboard: http://$ip:2379/dashboard (用户名: root, 密码为空)"
  echo "4. 系统服务管理:"
  echo "   - 启动: systemctl start tidb-${cluster_name}.service"
  echo "   - 停止: systemctl stop tidb-${cluster_name}.service"
  echo "   - 状态: systemctl status tidb-${cluster_name}.service"

  show_cluster_info $cluster_name
}

# 执行主函数
main