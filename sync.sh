#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd /home/horizon/Python-projects/longshot_tool/ || exit

echo -e "${BLUE}Examining Longshot Tools...${NC}"
git status -s

echo -e "${BLUE}Adding all changes...${NC}"
git add .

read -r -p "Enter Commit: (Enter as default: 'Update tool functionality'): " commit_msg
commit_msg=${commit_msg:-"Update tool functionality"}

git commit -m "$commit_msg"

echo -e "${BLUE}Sending to GitHub...${NC}"
git push origin main

echo -e "${GREEN}GitHub updated.${NC}"
