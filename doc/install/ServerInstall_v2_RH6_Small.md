# Introduction
This doc is for installing CIF v2 (small) on one of the following (minimum version given):

* CentOS 6.4
* RedHat 6.4
* Amazon Linux AMI 2013.09m

**SELINUX**

1. Disable SELINUX by setting `SELINUX=disabled` in `/etc/sysconfig/selinux`
2. Reboot


## Hadoop/HDFS/Hbase


[Install HBase/HDFS from Cloudera](Hadoop-HBase-RH6-Small.md). For ultra-small, you can locate this on the same server as CIF. For small, locate it on a single separate server. 

## CIF

1. Download CIF v2 tar file
2. Unpack
3. cd cif-v2-<date>
4. ./configure 
5. make install

Relevant configure options (defaults shown):

```
--prefix=/opt/cif
	installation dir
	
--with-user=cif 
--with-group=cif 
	control the ownership of the installation dir

--with-db-host=HOSTNAME
--with-db-port=PORT

--hdfs-dir=/var/lib/hadoop-hdfs/cache/hdfs
	database location (only relevant when doing make initdb on the db host)
```




