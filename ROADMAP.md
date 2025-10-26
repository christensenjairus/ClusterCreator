* Vmctl snapshot needs retries upon failures (bug)
* No SSH needed between external etcd and controlplanes
* Add a connectivity check to the template script before trying to install packages 
* Add a check at the end of the template script that ensures that the basic commands are installed and warns if they are not 
* Fix 'finding working control plane' sections. They can use the kube-vip address instead
* Add gVisor runtime along with runtimeclass 
* Add security packages like Falco and Sysdig