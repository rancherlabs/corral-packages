#!/bin/bash

kubectl wait --for=condition=Ready nodes --all --timeout=300s