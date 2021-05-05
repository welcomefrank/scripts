#!/bin/bash

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

returntobase(){
read -p "是否要返回主菜单? (默认按任意键返回主菜单/按N或n退出)" backtobase
if [ $backtobase = "N" -o $backtobase = "n" ];then
exit 0
else 
menu
fi
}

haproxyinstaller(){
yum install wget dmidecode net-tools psmisc haproxy -y
echo "NETWORKING=yes" >/etc/sysconfig/network
sysctl -w net.ipv4.ip_forward=1
sed -in-place -e "/net.ipv4.ip_forward/ d" -e "$a net.ipv4.ip_forward=1" /etc/sysctl.conf
sysctl -p
haproxy -f /etc/haproxy/haproxy.cfg
service haproxy restart
chkconfig haproxy on
chmod +x /etc/rc.d/rc.local
sed -in-place -e '$a /usr/local/haproxy/sbin/haproxy -f /usr/local/haproxy/haproxy.cfg' /etc/rc.d/rc.local
returntobase
}

addrule(){
read -p "请输入新增线路的名称：" rulename
read -p "请输入新增线路的前端口：" rulefrontendport
read -p "请输入新增线路的后端IP地址：" rulebackendip
read -p "请输入新增线路的后端口：" rulebackendport
clear
echo -e "刚刚输入的信息如下:\n新增线路的名称:$rulename\n新增线路的前端口:$rulefrontendport\n新增线路的后端IP地址:$rulebackendip\n新增线路的后端口:$rulebackendport"
read -p "按任意键确认 按n回车表示放弃并退出" confirmrule
if [ $confirmrule = "n" ];then
exit 0 
else
echo -e "已经确认新增线路信息 继续..."
fi
touch /root/haproxydata.txt
echo -e "#The following rules added on `date +20%y-%m-%d' '%H:%M:%S`" >> /root/haproxydata.txt  
echo -e "$rulename $rulefrontendport $rulebackendip $rulebackendport" >> /root/haproxydata.txt
cat /root/haproxydata.txt
touch /root/test.conf
cat >> /root/test.conf << EOF
frontend $rulename-in
        bind *:$rulefrontendport
        default_backend $rulename-out

backend $rulename-out
        server server1 $rulebackendip:$rulebackendport maxconn 20480

EOF
service haproxy restart
service haproxy status
cat /root/test.conf
returntobase
}

displayrules(){
cat /root/haproxydata.txt
returntobase
}

deleterule(){
cat /root/test.conf
read -p "请输入想要删除线路的前端口:" deleteport
sed -in-place -e "/$deleteport/ d" /root/haproxydata.txt 
sed -i "N;/\n.*$deleteport/!P;D" /root/test.conf
sed -in-place -e "/$deleteport/,+5d" /root/test.conf 
cat /root/test.conf
returntobase
}

firewalld_iptables(){
systemctl stop firewalld
systemctl disable firewalld
systemctl status firewalld
returntobase
}

addtcpport(){
yum install iptables-services -y
read -p "请输入新增的TCP端口：" newport
iptables -I INPUT -p tcp --dport $newport -j ACCEPT
service iptables save
service iptables restart
chkconfig iptables on
iptables -L -n
returntobase
}

addudprule(){
yum install iptables-services -y
chkconfig iptables on
read -p "请输入本服务器的UDP前端口：" sourcepport
read -p "请输入终端服务器的IP：" destinationip
read -p "请输入终端服务器的端口：" destinationport
iptables -t nat -A PREROUTING -p udp --dport $sourcepport -j DNAT --to-destination $destinationip:$destinationport
iptables -t nat -A POSTROUTING -p udp -d $destinationip --dport $destinationport -j MASQUERADE
service iptables save
service iptables restart
iptables -L -n
}

deleteudprule(){
iptables -L -n  --line-number
read -p "请输入需要删除的INPUT规则序列号：" linenumber
iptables -D INPUT $linenumber
service iptables save
service iptables restart
iptables -L -n
}

menu(){
    echo -e "${Red}中转服务器操作${Font}"
    echo -e "${Green}1.${Font} 仅安装Haproxy"
    echo -e "${Green}2.${Font} 新增中转线路"
    echo -e "${Green}3.${Font} 显示所有中转线路"
    echo -e "${Green}4.${Font} 删除指定中转线路"
    echo -e "${Green}5.${Font} 关闭firewalld服务"
    echo -e "${Green}6.${Font} 清空所有防火墙规则"
    echo -e "${Green}7.${Font} 安装iptables 并开启指定TCP端口"
    echo -e "${Green}8.${Font} 查看本机serverspeeder状态"
    echo -e "${Green}9.${Font} 显示本机全部已有端口"
    echo -e "${Green}10.${Font} 将指定端口流量清零"
    echo -e "${Green}11.${Font} 重启使所有规则生效"
    echo -e "${Green}12.${Font}  退出 \n"
    read -p "请输入数字：" menu_num
    case $menu_num in
        1)
          haproxyinstaller
        ;;
        2)
          addrule
        ;;
        3)
          displayrules
          ;;
        4)
          deleterule
          ;;         
        5)
          firewalld_iptables
          ;; 
        6)
          iptables -F
          echo -e "${Green}所有防火墙规则已经清空${Font}"
          ;; 
        7)
          addtcpport
          ;; 
        8)
          service serverspeeder status
          returntobase
          ;; 
        9)
          displayallports
          ;; 
        10)
          clearporttraffic
          ;; 
        11)
          reboot
          ;; 
        12)
          exit 0
          ;;
        *)
          echo -e "${RedBG}请输入正确的数字${Font}"
          ;;
    esac
}

menu