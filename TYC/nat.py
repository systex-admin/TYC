import json
import os
import sys
import re

vlan = sys.argv[1]
private_ip = sys.argv[2]
op_mode = sys.argv[3]
json_file = sys.argv[4]
f5_mode=""

class switch(object):
    def __init__(self, value):
        self.value = value
        self.fall = False

    def __iter__(self):
        """Return the match method once, then stop"""
        yield self.match
        raise StopIteration

    def match(self, *args):
        """Indicate whether or not to enter a case suite"""
        if self.fall or not args:
            return True
        elif self.value in args: # changed for v1.5, see below
            self.fall = True
            return True
        else:
            return False

def help():
    if 5 != len(sys.argv):
        print "[INFO]This is the name of the script:", sys.argv[0]
        print "[INFO]Number of arguments: ", len(sys.argv)
        print "[INFO]The arguments are: ", str(sys.argv)
        print "----------\n"
        print "Usage: python", sys.argv[0], "[Vlan_Number]" "[Private_IPv4] [User_NAT_Mode <add|del>] [NAT_JSON_File_Name]"
        print "DNAT Example: "
        print " python ", sys.argv[0], "124 10.241.62.101 add nat_list.json"
        print " python ", sys.argv[0], "124 10.241.62.101 del nat_list.json"
        print "SNAT Example: "
        print " python ", sys.argv[0], "124 10.251.62.201 add nat_list.json"
        print " python ", sys.argv[0], "124 10.251.62.201 del nat_list.json"
        print
        print "[ERROR] Wrong number of arguments."
        print
        exit(1)
    return sys.argv[1]

def check_10_ip(ipAddr):
    # dnat: 10.24X.[0-255].[101-112]
    compile_ip=re.compile("^(10)\.(24[0-1])\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(10[1-9]|11[0-2])$")
    if compile_ip.match(ipAddr):
        return "dnat"
    else:
        # snat: 10.25[0-1].[0-255].[10-250]
        #compile_ip=re.compile("^(10)\.(25[0-1])\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.([1-9]\d|1\d{2}|2[0-4]\d|250)$")
        # snat: 10.25X.[0-255].[201-212]
        compile_ip=re.compile("^(10)\.(25[0-1])\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(20[1-9]|21[0-2])$")
        if compile_ip.match(ipAddr):
            return "snat"
        else:
            return "failed"

def split_10_ip(ipAddr):
    addr=ipAddr.strip().split('.')
    if len(addr) != 4:
        print "[ERROR] Check ip address failed."
        exit(1)
    return addr

def split_163_30_ip(ipAddr, symbol):
    addr=ipAddr.strip().split(symbol)
    return addr

def bash_check_user_nat_list(header_name, private_ip):
    tmsh_list_cmd_str = "tmsh list ltm nat " + header_name + private_ip + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "was not found" in tmsh_log:
        exit(1)

def bash_delete_user_nat_list(header_name, private_ip):
    tmsh_list_cmd_str = "tmsh delete ltm nat " + header_name + private_ip + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "was not found" in tmsh_log:
        exit(1)

def bash_create_user_nat_list(header_name, private_ip, user_ext_ipv4):
    tmsh_list_cmd_str = "tmsh create ltm nat " + header_name + private_ip + " originating-address " + private_ip + " translation-address " + user_ext_ipv4 + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "already exists in partition Common" in tmsh_log:
        exit(1)

def bash_check_user_snat_list(header_name, snat_public_ip):
    tmsh_list_cmd_str = "tmsh list ltm snat " + header_name + snat_public_ip + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "was not found" in tmsh_log:
        exit(1)

def bash_delete_user_snat_list(header_name, snat_public_ip):
    tmsh_list_cmd_str = "tmsh delete ltm snat " + header_name + snat_public_ip + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "was not found" in tmsh_log:
        exit(1)

def bash_create_user_snat_list(header_name, snat_public_ip, private_prefix):
    tmsh_list_cmd_str = "tmsh create ltm snat " + header_name + snat_public_ip + " origins add { " + private_prefix + "} translation " + snat_public_ip + " 2>&1"
    tmsh_list_cmd = os.popen(tmsh_list_cmd_str)
    tmsh_log = tmsh_list_cmd.read()
    print tmsh_log
    if "already exists in partition Common" in tmsh_log:
        exit(1)

def dnat():
    help()
    header_private_ip = 101
    header_name = "nat_"
    private_ip_array = []
    private_ip_array = split_10_ip(private_ip)
    private_seg = str(private_ip_array[0]) + "." + str(private_ip_array[1]) + "." + str(private_ip_array[2]) + ".0"
    if int(private_ip_array[3]) < int(header_private_ip):
        print "[ERROR] private ip failed."
        exit(1)

    f = open(json_file)
    data = []
    data = json.load(f)

    addr_gap = int(private_ip_array[3]) - int(header_private_ip)
    int_gap_range_pool = int(addr_gap) + 1
    ext_range_pool = 0
    ext_range_start = 0
    ext_range_end = 0
    ext_split1 = []
    ext_split2 = []
    for i in range(len(data)):
        if (data[i]['vlan'] == vlan and \
            data[i]['seg'] == private_seg and \
            data[i]['dnat_new']):
            ext_split1 = split_163_30_ip(str(data[i]['dnat_new']), '-')
            ext_split2 = split_163_30_ip(str(ext_split1[0]), '.')
            ext_range_start = int(ext_split2[3])
            ext_range_end = int(ext_split1[1])
            ext_range_pool = ext_range_end - ext_range_start + 1
            if int_gap_range_pool > ext_range_pool:
                addr_gap = addr_gap - ext_range_pool
                int_gap_range_pool = int(addr_gap) + 1
                continue

            user_ext_8bit_ipv4 = ext_range_start + addr_gap
            ext_and_netmask= str(ext_split2[0]) + "." + str(ext_split2[1]) + "." + str(ext_split2[2])
            user_ext_ipv4 = str(ext_and_netmask) + "." + str(user_ext_8bit_ipv4)
            print "[INFO] User Vlan: ", data[i]['vlan']
            print "[INFO] User Private IP: ", private_ip
            print "[INFO] User Public IP: ", user_ext_ipv4
            print "[INFO] User DNAT External Range Pool: ", ext_range_pool
            print "[INFO] External ", ext_and_netmask, " Range Pool: ", ext_range_start, " to ", ext_range_end

            if op_mode == "show":
                bash_check_user_nat_list(header_name, private_ip)
            elif op_mode == "add":
                bash_create_user_nat_list(header_name, private_ip, user_ext_ipv4)
            elif op_mode == "del":
                bash_delete_user_nat_list(header_name, private_ip)
            else:
                print "[ERROR] User Mode failed."
                exit(1)

def snat():
    help()
    header_name = "snat_"
    private_ip_array = []
    private_ip_array = split_10_ip(private_ip)
    private_prefix = str(private_ip_array[0]) + "." + str(private_ip_array[1]) + "." + str(private_ip_array[2]) + ".0/24"

    f = open(json_file)
    data = []
    data = json.load(f)
    
    for i in range(len(data)):
        if (data[i]['vlan'] == vlan):
            private_ip_array = []
            private_ip_array = split_10_ip(private_ip)

            print "[INFO] User Vlan: ", data[i]['vlan']
            print "[INFO] User SNAT Address/Prefix: ", private_prefix
            print "[INFO] User SNAT Public IP: ", data[i]['snat']
            
            if op_mode == "show":
                bash_check_user_snat_list(header_name, data[i]['snat'])
            elif op_mode == "add":
                bash_create_user_snat_list(header_name, data[i]['snat'], private_prefix)
            elif op_mode == "del":
                bash_delete_user_snat_list(header_name, data[i]['snat'])
            else:
                print "[ERROR] User Mode failed."
                exit(1)

def main():
    f5_mode = check_10_ip(private_ip)

    for case in switch(f5_mode):
        if case("dnat"):
            dnat()
            break
        if case("snat"):
            snat()
            break
        if case("failed"):
            print "[ERROR] Check for Private IP error."
            exit(1)

if __name__ == '__main__':
    main()


