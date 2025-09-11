#!/bin/bash
apt update
apt upgrade -y
apt autoremove
apt install wget -y

setup_color() {
    # Only use colors if connected to a terminal
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        BOLD=""
        RESET=""
    fi
}

setup_color

username=`whoami`
if [[ ! ${username} == "root" ]];then
    echo "${RED}请使用root用户执行该脚本${RESET}"
    exit
fi

n=`sudo grep -n "ClientAliveInterval " /etc/ssh/sshd_config | awk -F':' '{print $1}'`
TMPn='ClientAliveInterval 60'
m=`sudo grep -n "ClientAliveCountMax " /etc/ssh/sshd_config | awk -F':' '{print $1}'`
TMPm='ClientAliveCountMax 3'
sudo sed -i "$[ n ]c $TMPn" /etc/ssh/sshd_config
sudo sed -i "$[ m ]c $TMPm" /etc/ssh/sshd_config

echo "即将更新软件源信息"
apt update
echo "即将安装依赖软件"
apt install -y git zsh gcc g++ glibc-doc autojump universal-ctags

echo "即将下载环境配置脚本"
wget wiki.haizeix.com/courses_resource/cloud_usage/isoftstone_env.sh

regex="^[a-zA-Z]+$"

while [[ 1 ]];do
    read -p "请设置一个${RED}主机名字${RESET}(${YELLOW}纯英文${RESET}) :" host_name
    if [[ ! ${host_name} =~ ${regex} ]];then
        echo "${RED}主机名不符合规则，请重新输入${RESET}"
        continue
    else
        break
    fi
done

hostnamectl set-hostname ${host_name}
echo "名字切换完成"
host_ip=`ifconfig eth0 |grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#echo $host_ip
host_isoftstone_xiaokai=`grep -n "$host_ip" /etc/hosts | head -1 | awk -F':' '{print $1}'`
host_isoftstone_xiaokai=${host_isoftstone_xiaokai[0]}

if [ ! -n "$host_isoftstone_xiaokai" ]; then
    echo "未查询到，尾部追加数据"
    echo "$host_ip	${host_name}	${host_name}" >> /etc/hosts
else 
    echo "已查询到，文件内容替换"
    host_isoftstone_xiaokai_TMP="$host_ip	${host_name}	${host_name}"
    #bool_isoftstone_xiaokai=`sudo grep -n '%sudo	ALL=(ALL:ALL) ALL' /etc/sudoers | awk -F':' '{print $1}'`
    sed -i "$[ host_isoftstone_xiaokai ]c $host_isoftstone_xiaokai_TMP" /etc/hosts
fi
echo "${host_name} 欢迎同学!"

while [[ 1 ]];do
    read -p "请输入你的${RED}用户名${RESET}（${YELLOW}必须英文${RESET}） :" username
    if [[ ! ${username} =~ ${regex} ]];then
        echo "${RED}您的用户名不符合规则，请重新输入${RESET}"
        continue
    else
        break
    fi
done

while [[ 1 ]];do
    read -p "请为用户${BLUE}${username}${RESET}设置一个${RED}密码${RESET} :" USER_PASSWD
    read -p "你的密码为${GREEN}${USER_PASSWD}${RESET},请输入${YELLOW}y${RESET}确认,其他任何字符将重新设置密码 [y/n]:" in_tmp
    if [[ ${in_tmp} == 'y' ]];then
        break
    else
        continue
    fi
done

#username=new_user16

useradd  ${username} -G sudo -m && echo "Add user successfully" ||( userdel -rf ${username}; echo "User del ${username}" && useradd ${username} -G sudo -m  && echo "Add user successfully")

sleep 1
(
    sleep 1
    echo ${USER_PASSWD}
    sleep 1
    echo ${USER_PASSWD}
)|passwd ${username}

if [ $? -eq 0 ];
    then
    echo "PASSWD changed successfully"
    else
    echo "PASSWD change failed"
    exit
fi

echo "用户配置完成"
#sudo cp kkv_env.sh /home/new_user/


cp isoftstone_env.sh /home/${username}/
chown ${username} /home/${username}/isoftstone_env.sh
chgrp ${username} /home/${username}/isoftstone_env.sh
chmod a+x /home/${username}/isoftstone_env.sh

#sudo cp kkv_env.sh /home/new_user/
#su new_user -c "sudo bash kkv_env.sh"
#su -oracle -s new_user -c `sudo bash kkv_env.sh`
#sudo echo 'root ALL = NOPASSWD:ALL' >> /etc/sudoers
q=`grep -n '%sudo	ALL=(ALL:ALL) ALL' /etc/sudoers | awk -F':' '{print $1}'`
#echo "q"$q

if [ ! -n "$q" ]; then
    echo "sudo命令权限已经改变"
else 
    TMPq='%sudo	ALL=(ALL:ALL) NOPASSWD: ALL'
    sed -i "$[ q ]c $TMPq" /etc/sudoers
    echo "sudo权限修改完成"
fi
#num=`cat -n /etc/sudoers|grep 'Defaults   visiblepw'|awk '{print $1}'`
num=`grep -n 'Defaults   visiblepw' /etc/sudoers | awk -F':' '{print $1}'`
#echo $num
if [ ! -n "$num" ]; then
  echo "Defaults visiblepw IS NULL"
  sudo echo 'Defaults   visiblepw' >> /etc/sudoers
else
  echo "Defaults visiblepw NOT NULL"
fi

#if [ $num ]; then
#    echo "有内容"
#else 
#    echo "没有内容，添加内容"
#    sudo echo 'Defaults   visiblepw' >> /etc/sudoers
#fi
su - $username -c "bash isoftstone_env.sh $username ${USER_PASSWD}"

rm /home/$username/install_vim.sh*
rm /home/$username/isoftstone_env.sh*
rm /home/$username/install_zsh.sh*


l=`grep -n '%sudo	ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers | awk -F':' '{print $1}'`
if [ ! -n "$l" ]; then
    echo "sudo 命令不用修改或检查命令是否为原文件"
else 
    TMPl='%sudo	ALL=(ALL:ALL) ALL'
    sudo sed -i "$[ l ]c $TMPl" /etc/sudoers
    echo "sudo 内容已经恢复"
fi

#rm $username /home/$username/install_vim.sh*
#rm $username /home/$username/isoftstone_env.sh
#rm $username /home/$username/install_zsh.sh*
cd
rm ./init_env.sh
rm ./isoftstone_env.sh
echo -e "你的用户名${BLUE}${username}${RESET},密码为${GREEN}${USER_PASSWD}${RESET}\n请使用新用户登录系统"
su - ${username}
#sudo bash isoftstone_env.sh
