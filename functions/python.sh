#!/usr/bin/env bash

pyclean() {
  find . -type f -name "*.py[co]" -print -delete
  find . -type d -name "__pycache__" -print -delete
}
