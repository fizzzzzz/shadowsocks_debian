#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  Debian or Ubuntu (32bit/64bit)
#   Description: Install Shadowsocks-libev server for Debian or Ubuntu
#   Author: Teddysun <i@teddysun.com>
#   Thanks: @m0d8ye <https://twitter.com/m0d8ye>
#   Intro:  http://teddysun.com/358.html
#===============================================================================================

clear
echo ""

# Install Shadowsocks-libev
function install_shadowsocks_libev(){
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    install_libev
    change_iptables
    start_shadowsocks
}

# Make sure only root can run our script
function rootness(){
if [[ $EUID -ne 0 ]]; then
   echo "Error:This script must be run as root!" 1>&2
   exit 1
fi
}

# Disable selinux
function disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}

# Pre-installation settings
function pre_install(){
    #Set shadowsocks-libev config password
#    echo "Please input password for shadowsocks-libev:"
#    read -p "(Default password: teddysun.com):" shadowsockspwd
    [ -z "$shadowsockspwd" ] && shadowsockspwd="16021incloud"
#    echo ""
#    echo "---------------------------"
#    echo "password = $shadowsockspwd"
#    echo "---------------------------"
#    echo ""
    #Set shadowsocks-libev config port
#    while true
#    do
#    echo -e "Please input port for shadowsocks-libev [1-65535]:"
#    read -p "(Default port: 8989):" shadowsocksport
    [ -z "$shadowsocksport" ] && shadowsocksport="10665"
#    expr $shadowsocksport + 0 &>/dev/null
#    if [ $? -eq 0 ]; then
#        if [ $shadowsocksport -ge 1 ] && [ $shadowsocksport -le 65535 ]; then
#            echo ""
#            echo "---------------------------"
#            echo "port = $shadowsocksport"
#            echo "---------------------------"
#            echo ""
#            break
#        else
#            echo "Input error! Please input correct numbers."
#        fi
#    else
#        echo "Input error! Please input correct numbers."
#    fi
#    done
#    get_char(){
#        SAVEDSTTY=`stty -g`
#        stty -echo
#        stty cbreak
#        dd if=/dev/tty bs=1 count=1 2> /dev/null
#        stty -raw
#        stty echo
#        stty $SAVEDSTTY
#    }
#    echo ""
#    echo "Press any key to start...or Press Ctrl+C to cancel"
#    char=`get_char`
    # Update System
    apt-get -y update
    # Install necessary dependencies
    apt-get install -y wget unzip curl build-essential autoconf libtool libssl-dev
    # Get IP address
#    echo "Getting Public IP address, Please wait a moment..."
    IP=$(curl -s -4 icanhazip.com)
    if [[ "$IP" = "" ]]; then
        IP=$(curl -s -4 ipinfo.io | grep "ip" | awk -F\" '{print $4}')
    fi
#    echo -e "Your main public IP is\t\033[32m$IP\033[0m"
#    echo ""
    #Current folder
    cur_dir=`pwd`
    cd $cur_dir
}

#change iptables settings
function change_iptables() {
    iptables-save> /tmp/current_iptables.rules
    cat /tmp/current_iptables.rules |grep -v '# Completed' |grep -v 'COMMIT' > /tmp/current_iptables.rules.tmp
    echo "-A INPUT -s 119.80.62.0/24 -p tcp -m tcp --dport 7890 -j ACCEPT" >> /tmp/current_iptables.rules.tmp
    echo "COMMIT" >> /tmp/current_iptables.rules.tmp
    cp /tmp/current_iptables.rules.tmp /etc/iptables.test.rules
    iptables-restore < /etc/iptables.test.rules
    iptables-save > /etc/iptables.up.rules

}


function start_shadowsocks() {
    /etc/init.d/shadowsocks restart
    cd /etc/shadowsocks-libev/
    nohup ss-local -c config.json > /dev/null 2>&1 &
}

# Download latest shadowsocks-libev
function download_files(){
    if [ -f shadowsocks-libev.zip ];then
        echo "shadowsocks-libev.zip [found]"
    else
        if ! wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/master.zip -O shadowsocks-libev.zip;then
            echo "Failed to download shadowsocks-libev.zip"
            exit 1
        fi
    fi
    unzip shadowsocks-libev.zip
    if [ $? -eq 0 ];then
        cd $cur_dir/shadowsocks-libev-master/
        if ! wget --no-check-certificate https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-libev-debian; then
            echo "Failed to download shadowsocks-libev start script!"
            exit 1
        fi
    else
        echo ""
        echo "Unzip shadowsocks-libev failed! Please visit http://teddysun.com/358.html and contact."
        exit 1
    fi
}

# Config shadowsocks
function config_shadowsocks(){
    if [ ! -d /etc/shadowsocks-libev ];then
        mkdir /etc/shadowsocks-libev
    fi
    cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "local_address":"0.0.0.0",
    "local_port":7890,
    "password":"${shadowsockspwd}",
    "timeout":600,
    "method":"aes-256-cfb"
}
EOF
}

# Install 
function install_libev(){
    # Build and Install shadowsocks-libev
    if [ -s /usr/local/bin/ss-server ];then
        echo "shadowsocks-libev has been installed!"
        exit 0
    else
        ./configure
        make && make install
        if [ $? -eq 0 ]; then
            # Add run on system start up
            mv $cur_dir/shadowsocks-libev-master/shadowsocks-libev-debian /etc/init.d/shadowsocks
            chmod +x /etc/init.d/shadowsocks
            update-rc.d shadowsocks defaults
            # Run shadowsocks in the background
            /etc/init.d/shadowsocks start
            # Run success or not
            if [ $? -eq 0 ]; then
                echo "Shadowsocks-libev start success!"
            else
                echo "Shadowsocks-libev start failure!"
            fi
        else
            echo ""
            echo "Shadowsocks-libev install failed! Please visit http://teddysun.com/358.html and contact."
            exit 1
        fi
    fi
    cd $cur_dir
    # Delete shadowsocks-libev floder
    rm -rf $cur_dir/shadowsocks-libev-master/
    # Delete shadowsocks-libev zip file
    rm -f shadowsocks-libev.zip
}

# Uninstall Shadowsocks-libev
function uninstall_shadowsocks_libev(){
    printf "Are you sure uninstall Shadowsocks-libev? (y/n) "
    printf "\n"
    read -p "(Default: n):" answer
    if [ -z $answer ]; then
        answer="n"
    fi
    if [ "$answer" = "y" ]; then
        ps -ef | grep -v grep | grep -v ps | grep -i "ss-server" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        # remove auto start script
        update-rc.d -f shadowsocks remove
        # delete config file
        rm -rf /etc/shadowsocks-libev
        # delete shadowsocks
        rm -f /usr/local/bin/ss-local
        rm -f /usr/local/bin/ss-tunnel
        rm -f /usr/local/bin/ss-server
        rm -f /usr/local/bin/ss-redir
        rm -f /usr/local/lib/libshadowsocks.a
        rm -f /usr/local/lib/libshadowsocks.la
        rm -f /usr/local/include/shadowsocks.h
        rm -rf /usr/local/lib/pkgconfig
        rm -f /usr/local/share/man/man8/shadowsocks.8
    else
        echo "uninstall cancelled, Nothing to do"
    fi
}



# Initialization step
action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocks_libev
    ;;
uninstall)
    uninstall_shadowsocks_libev
    ;;
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac

