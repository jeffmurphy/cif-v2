#!/bin/sh 


rh_compatible() {
	echo "*** Configuring HBase for RedHat/CentOS/Amazon single-server (small)"
        yum -y install java curl
        rpm --import http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera
        curl -o /etc/yum.repos.d/cloudera-chd4.repo http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/cloudera-cdh4.repo
        yum -y install hbase-master hbase-regionserver hbase-thrift hadoop-hdfs hadoop-hdfs-namenode hadoop-hdfs-datanode
        cp ../doc/install/small/hadoop-core-site.xml /etc/hadoop/conf/core-site.xml
        cp ../doc/install/small/hdfs-site.xml /etc/hadoop/conf/hdfs-site.xml
        su - hdfs -c 'hdfs namenode -format'
        service hadoop-hdfs-namenode start
        service hadoop-hdfs-datanode start
        cp ../doc/install/small/hbase-site.xml /etc/hbase/conf/
        su -  hdfs  -c 'hdfs dfs -mkdir /hbase'
        su -  hdfs  -c 'hdfs dfs -chown hbase /hbase'
        service hbase-master start
        service hbase-thift start
        echo "*** If you aren't running cif-db on this machine, open iptables inbound, tcp, port 2181 so cif-db can connect"
        hbase shell < hbase-tables.txt   # ignore any errors about tables not existing
}


if [[ $EUID -ne 0 ]]; then
   echo "$0: This script must be run as root" 1>&2
   exit 1
fi

R=`lsb_release -a | grep Distributor | cut -d : -f 2 | sed 's/[\t\s]//g'`
case "$R" in
	CentOS|RedHat|AmazonAMI)
		rh_compatible
		;;
	*) 
		echo "not sure what to do with $R -- install by hand. sorry."
		;;
esac

exit 0


