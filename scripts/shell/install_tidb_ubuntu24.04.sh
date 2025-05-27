#!/bin/bash

# TiDB单机模拟部署脚本
# 功能：在单台Linux服务器上部署最小拓扑的TiDB集群

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root用户运行此脚本"
  exit 1
fi

# 安装TiUP
install_tiup() {
  echo "正在安装TiUP..."
  curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
  source ${HOME}/.bashrc
}

# 安装cluster组件
install_cluster_component() {
  echo "正在安装TiUP cluster组件..."
  tiup cluster
  tiup update --self && tiup update cluster
}

# 调整sshd配置
adjust_sshd_config() {
  echo "调整sshd配置..."
  sed -i 's/^#MaxSessions 10/MaxSessions 20/' /etc/ssh/sshd_config
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
  apt-get -y install mysql-client
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
  local ip="192.168.0.7"  # 替换为实际IP
  local cluster_name="tidb-test-cluster"
  local version="v8.5.1"  # 可以修改为需要的版本

  echo "===== TiDB单机模拟部署开始 ====="

  # 执行部署步骤
  install_tiup
  install_cluster_component
  adjust_sshd_config
  deploy_cluster $ip $cluster_name $version
  start_cluster $cluster_name
  install_mysql_client

  # 显示部署结果
  echo "===== 部署完成 ====="
  echo "1. 使用MySQL客户端连接TiDB:"
  echo "   mysql -h $ip -P 4000 -u root"
  echo "2. 访问Grafana监控: http://$ip:3000 (用户名/密码: admin/admin)"
  echo "3. 访问TiDB Dashboard: http://$ip:2379/dashboard (用户名: root, 密码为空)"

  show_cluster_info $cluster_name
}

# 执行主函数
main