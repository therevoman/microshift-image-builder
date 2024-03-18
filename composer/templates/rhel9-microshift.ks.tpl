lang en_US.UTF-8
keyboard --xlayouts='us'
timezone America/Denver --isUtc

##############################################################
# Disk and Partitions
######################################################
zerombr
ignoredisk --only-use=nvme0n1
clearpart --all --initlabel
part /boot/efi --size 512 --asprimary --fstype=efi --ondrive=nvme0n1
part /boot --size 1024 --asprimary --fstype=xfs --ondrive=nvme0n1
part pv.01 --size 1 --grow --fstype=xfs --ondrive=nvme0n1
volgroup rhel --pesize=32768 pv.01
logvol / --fstype xfs --vgname=rhel --size=98304 --name=root
logvol /home --fstype xfs --vgname=rhel --size=51200 --name=home
logvol /var --fstype xfs --vgname=rhel --size=51200 --name=var
logvol /var/log --fstype xfs --vgname=rhel --size=15360 --name=var_log
logvol /var/log/audit --fstype xfs --vgname=rhel --size=15360 --name=var_log_audit
logvol /opt --fstype xfs --vgname=rhel --size=51200 --name=opt


##############################################################
# Prepare for and kickoff ostree install
######################################################
reboot
text
#network --bootproto=dhcp
network  --bootproto=dhcp --device=enp1s0 --onboot=on --ipv6=auto --activate
rootpw --iscrypted ${ROOT_SSH_PASSWORD}
services --enabled=ostree-remount
group --name=admin --gid=1000
user --name=admin --gecos="Administrator" --uid=1000 --gid=1000 --groups=users,wheel --password ${ADMIN_SSH_PASSWORD} --iscrypted
group --name=nrevo --gid=1001
user --name=nrevo --gecos="Nate Revo" --uid=1001 --gid=1001 --groups=users,wheel --password ${USER_SSH_PASSWORD} --iscrypted
# --url = location of repo --osname=stateroot=distro --remote=just_a_label_for_counting --ref=branch
ostreesetup --nogpg --url=${OSTREE_REPO_URL} --osname=rhel --remote=edge --ref=rhel/9/x86_64/edge

##############################################################
# Post Install directives
######################################################
%post --log=/var/log/anaconda/post-install.log
# Update certificate trust storage in case new certificates were
# installed at /etc/pki/ca-trust/source/anchors directory
update-ca-trust
%end

%post --log=/var/log/anaconda/post-install.log --erroronfail
# Add the pull secret to CRI-O and set root user-only read/write permissions
cat > /etc/crio/openshift-pull-secret << EOF
${PULL_SECRET}
EOF
chmod 600 /etc/crio/openshift-pull-secret
%end

%post --log=/var/log/anaconda/post-install.log --erroronfail
# Configure the firewall with the mandatory rules for MicroShift
firewall-offline-cmd --zone=trusted --add-source=10.42.0.0/16
firewall-offline-cmd --zone=trusted --add-source=169.254.169.1
firewall-offline-cmd --zone=public --add-port=6443/tcp
firewall-offline-cmd --zone=public --add-port=80/tcp
firewall-offline-cmd --zone=public --add-port=443/tcp
%end

%post --log=/var/log/anaconda/post-install.log
# additional updates
echo -e '${SSH_USER}\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
echo -e 'url=https://httpd.revoweb.com/redhat/ostree/repo' >> /etc/ostree/remotes.d/edge.conf
# preconfigure kube config for users
mkdir -p /home/admin/.kube
cp /var/lib/microshift/resources/kubeadmin/kubeconfig /home/admin/.kube/config
chown -R admin:admin /home/admin/.kube
mkdir -p /home/${SSH_USER}/.kube
cp /var/lib/microshift/resources/kubeadmin/kubeconfig /home/${SSH_USER}/.kube/config
chown -R admin:admin /home/${SSH_USER}/.kube
%end
