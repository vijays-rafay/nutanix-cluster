#cloud-config
hostname: ${hostname}
users:
  - name: ubuntu
    passwd: '$6$rounds=4096$23GLKxe5CyPc1$fL5FgZCbCgw30ZHwqDt8hoO07m6isstJlxUIwvHBcSLVGzjdiR1Z1zA2yKGtR6EIv5LHflJuedbaiLUqU5Wfj0'
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    lock_passwd: false
    shell: /bin/bash
    ssh-authorized-keys:
      - ${ssh_public_key} 
