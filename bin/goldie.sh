#! /bin/sh

ulimit -n 60000 
cd /opt/app
exec  mix run --no-halt

