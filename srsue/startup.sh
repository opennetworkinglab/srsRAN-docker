#!/bin/bash

ip netns add ue1

cd /opt

./srsue ue_zmq.conf
