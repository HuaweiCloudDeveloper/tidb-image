locals {
  // you need to specify a unique name under a tenant according to the business, which will be used as part of the resource name
  app_id = format("%s-%s", "app", formatdate("hhmm", timestamp()))

  name_suffix = "mkp"

  // Tags of HUAWEI CLOUD resources. You can add tags to resources to classify resources.
  // for more details, please refer to https://support.huaweicloud.com/usermanual-tms/zh-cn_topic_0056266263.html
  tags = { Purpose = "MkpApplication" }



  # Configuration of the ECS memory size and number of cores
  # instance_flavor_cpu    = 4
  # instance_flavor_memory = 16
  #  通用计算增强型
  instance_performance_type = "kunpeng_computing"
  # 系统盘: 通用SSD
  ecs_volume_type = "GPSSD"

  # 规格：通用入门型
  #ecs_flavor = "kc1.xlarge.4"

  // Billing model for cloud resources, You need to modify it according to your actual situation.
  // In the development and testing phase, pay-per-use billing is recommended.
  // You can also set these three parameters as variables, allowing users to select at deployment time.
  charging_mode = var.charging_mode
  period_unit   = var.period_unit
  period        = var.period

  // The billing model for bandwidth, You need to modify it according to your actual situation.
  publicip_type         = "5_bgp"     # 全动态
  bandwidth_share_type  = "PER"       # 独享带宽
  bandwidth_charge_mode = "bandwidth" # 按带宽计费
  bandwidth_size        = 10          # 带宽大小

  # Image information in different regions, you need to enter your own image ID or add another region.
  # For Marketplace Image Id,you can log in to Seller Console, view the marketplace image id on Product Specifications section of My Products detail page.
  # 镜像版本：
  #TiDB8.5.1-HCE2.0
  instance_image_id_maps_v1 = {
#     北京4
    cn-north-4     = "e5ac8ceb-a65f-4ee6-bcd7-23051130e533"
#     广州
    cn-south-1     = "1ad46075-0e10-466f-85d0-c259371d7155"
#     上海一
    cn-east-3      = "138b974b-5d8e-4777-833b-cb366595b300"
#     乌兰察布一
    cn-north-9     = "9478c235-0d12-4efa-b50e-7c674dd7e029"
#     贵阳一
    cn-southwest-2 = "032b1299-6ca1-4f2f-8f8c-be6f9da89709"

  }
  #TiDB8.5.1-Ubuntu24.04
  instance_image_id_maps_v2 = {
#     北京4
    cn-north-4     = "30d7c984-870a-44c7-9f45-05a03ea7d91b"
#     广州
    cn-south-1     = "c6459d74-8159-4b84-a21e-d89eff7ecc9b"
#     上海一
    cn-east-3      = "89ba62fc-4f9b-4880-ac97-b673368390f5"
#     乌兰察布一
    cn-north-9     = "42a8711a-f4a1-425e-bd10-d50320d4a344"
#     贵阳一
    cn-southwest-2 = "fd0aa6cf-702f-40af-9230-d4a3b72b4e34"

  }  
  # # 其他版本增加（注意修改var参数和镜像的版本的判断部分）
  #  instance_image_id_maps = {
  #   #     北京4
  #   cn-north-4 = ""
  #  }  

  # Specifies the DNS server address list of a subnet. For details about the private DNS address, see https://support.huaweicloud.com/dns_faq/dns_faq_002.html#?
  subnet_dns_list_maps = {
    cn-north-4     = ["100.125.1.250", "100.125.129.250"]
    cn-south-1     = ["100.125.1.250", "100.125.136.29"]
    cn-east-3      = ["100.125.1.250", "100.125.64.250"]
    cn-north-9     = ["100.125.1.250", "100.125.107.250"]
    cn-southwest-2 = ["100.125.1.250", "100.125.129.250"]
  }


}