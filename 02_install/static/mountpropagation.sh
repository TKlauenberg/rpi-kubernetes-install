#!/bin/sh


# kubernetes expects that it runs with /
# see: https://github.com/kubernetes/kubernetes/issues/61058
mount --make-rshared /

# Simulate a daemon
sleep infinity
