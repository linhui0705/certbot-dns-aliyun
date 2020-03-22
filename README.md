# certbot-dns-aliyun

## How to use?
1. Download from GitHub
```
git clone https://github.com/linhui0705/certbot-dns-aliyun.git
chmod 755 startup.sh
```

2. Create user and set Permission
Log in to alicloud console. Create a new user and set permissions in RAM console.
https://ram.console.aliyun.com/

3. Apply AccessKey
Apply accessKey and modify file startup.sh.
Modify AccessKeyId, AccessKeySecret, path and your domain name. 

4. Startup
./startup.sh