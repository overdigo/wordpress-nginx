#!/bin/bash
wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
chmod ug+x mysqltuner.pl
./mysqltuner.pl
