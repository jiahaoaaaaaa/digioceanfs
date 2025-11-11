#!/bin/bash

################################################################
# 路径及版本配置
################################################################
# codePath: 代码路径
codePath='/home/test/glfs/glusterfs-10.5'
# tmpPath: 打包过程中临时存放目录
#          该目录下需要包含脚本 cl_string_replace.sh
tmpPath='/root/rpmtmp'

# branch：打包分支
branch='digioceanfs-base-10'
# version：要打包的tag
#          如果没有相应tag，则为分支名称；也可以为commit号
version='digioceanfs-10-1'
# release：版本号
release='1'
# rpmPath：打包完成后，存放rpm包的路径
rpmPath='/root/RPMS/'

#version='digioceanfs-10.0-56'
#version='996086bb2d8764f64f5544cb7eb4816e58774df8'

#branch='Infinova-nodatabase'
#version='Infinova-nodatabase'
#release='68.4'

#branch='Infinova-base-66'
#version='Infinova-base-66'
#release='66.inf.11'

# 系统架构类型的获取
arch=`arch`

if [ ! -d $tmpPath ]
then
    mkdir -p $tmpPath
fi


cp cl_string_replace.sh $tmpPath

################################################################
# 配置rpmbuild目录
################################################################
if [ ! -d /root/rpmbuild ]; then
    mkdir /root/rpmbuild/
        for dir in BUILD  BUILDROOT  RPMS  SOURCES  SPECS  SRPMS; do mkdir /root/rpmbuild/${dir}; done
fi



################################################################
# 将git上的管理系统代码 制作成打包需要的压缩包
################################################################
cd $codePath
git checkout $branch
# git pull

commitID=`git log -n 1 | grep '^commit' | awk '{print $2}'`
git archive --format=tar $version | gzip > digioceanfs-10.0.tar.gz

mv digioceanfs-10.0.tar.gz $tmpPath
cd $tmpPath
rm -rf digioceanfs-10.0
mkdir digioceanfs-10.0
tar xzvmf digioceanfs-10.0.tar.gz -C digioceanfs-10.0
./cl_string_replace.sh digioceanfs-10.0 --gtod


################################################################
# 修改打包脚本spec中的release版本号
# 将打包脚本spec，放到/root/rpmbuild/SPECS/目录
# 将压缩包放到/root/rpmbuild/SOURCES/目录
################################################################
cd have-changed

# 处理spec脚本
sed -i 's/Name: .*/Name:             digioceanfs/g' digioceanfs-10.0/digioceanfs.spec
sed -i 's/Version: .*/Version:          10.0/g' digioceanfs-10.0/digioceanfs.spec
sed -i 's/Release: .*/Release:          '$release'/g' digioceanfs-10.0/digioceanfs.spec
sed -i 's/Source0: .*/Source0:          digioceanfs-10.0.tar.gz/g' digioceanfs-10.0/digioceanfs.spec
cp digioceanfs-10.0/digioceanfs.spec /root/rpmbuild/SPECS/digioceanfs-10.0.spec

# 处理源码压缩包
tar czvmf digioceanfs-10.0.tar.gz digioceanfs-10.0
cp digioceanfs-10.0.tar.gz /root/rpmbuild/SOURCES/


# if [ "$arch" = "aarch64" ]
# then
#     sed -i '7 a %define __debug_install_post   \\' /root/rpmbuild/SPECS/digioceanfs-10.0.spec
#     sed -i '8 a \ \ %{_rpmconfigdir}/find-debuginfo.sh %{?_find_debuginfo_opts} "%{_builddir}/%{?buildsubdir}"\\' /root/rpmbuild/SPECS/digioceanfs-10.0.spec
#     sed -i '9 a %{nil}' /root/rpmbuild/SPECS/digioceanfs-10.0.spec
# fi

################################################################
# 通过rpmbuild -ba 命令打包
################################################################
if [ "$arch" = "aarch64" ]
then
    rpmbuild -ba /root/rpmbuild/SPECS/digioceanfs-10.0.spec --nodeps > $tmpPath/rpmbuild_glusterfs_log_`date '+%Y%m%d%H'`
else
    rpmbuild -ba /root/rpmbuild/SPECS/digioceanfs-10.0.spec > $tmpPath/rpmbuild_glusterfs_log_`date '+%Y%m%d%H'`
fi



################################################################
# 创建文件系统的release版本目录
################################################################
releaseRpmPath=$rpmPath/$branch/$arch/digioceanfs-10.0-$release
if [ ! -d $releaseRpmPath ]
then
    mkdir -p $releaseRpmPath
fi


########################################################################
# 将打包后/root/rpmbuild/RPMS/<arch>/目录下的rpm包，放入相应release目录
########################################################################
RPMList='digioceanfs digioceanfs-api digioceanfs-api-devel digioceanfs-cli digioceanfs-client-xlators digioceanfs-debuginfo digioceanfs-devel digioceanfs-extra-xlators digioceanfs-fuse digioceanfs-geo-replication digioceanfs-libs digioceanfs-rdma digioceanfs-regression-tests digioceanfs-server'

for rpmpak in $RPMList
do
    rpmpakpath='/root/rpmbuild/RPMS/'$arch'/'$rpmpak'-3.7.12-'$release'.'$arch'.rpm'
    if [ -e $rpmpakpath ]
    then
        cp $rpmpakpath $releaseRpmPath
    else
        echo 'Not found'$rpmpakpath
    fi
done

if [ -e /root/rpmbuild/RPMS/noarch/python-digiocean-3.7.12-$release.noarch.rpm ]
then
    cp /root/rpmbuild/RPMS/noarch/python-digiocean-3.7.12-$release.noarch.rpm $releaseRpmPath
else
    echo 'Not found /root/rpmbuild/RPMS/noarch/python-digiocean-3.7.12-'$release'.noarch.rpm'
fi



################################################################
# 将release版本目录打包
################################################################
pushd $rpmPath/$branch/$arch/
tar cvfzm digioceanfs-10.0-$release.tar.gz digioceanfs-10.0-$release
popd



################################################################
# 将基础信息输出到终端
################################################################
echo '###################################################################################################'
echo '#'
echo '#                 当前分支: '$branch
echo '#                 当前版本: digioceanfs-10.0-'$release
echo '#       当前版本 Commit ID: '$commitID
echo '#'
echo '#        文件系统rpm包路径: '$releaseRpmPath
echo '#'
echo '###################################################################################################'


