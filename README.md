# wordpress-nginx

Nginx.conf
```javascript
wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/nginx/nginx.conf
```
My.cnf
```javascript
wget -O /etc/mysql/my.cnf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/mysql/my.cnf
```


mysqltuner
```javascript
bash <(wget -O - https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/mysqltuner.sh)
```

Bench
```javascript
wget https://freevps.us/downloads/bench.sh -O - -o /dev/null|bash
```
