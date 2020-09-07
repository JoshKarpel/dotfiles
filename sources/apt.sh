#!/usr/bin/env bash

function apt-up() {
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt autoremove -y
}
