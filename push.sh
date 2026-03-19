git add .
git status

# 날짜 포함된 커밋 메시지 생성
current_date=$(date +"%Y-%m-%d %H:%M:%S")
commit_message="Update - $current_date"
git commit -m "$commit_message"
git push origin main

echo "Changes have been committed and pushed to the main branch with the message: '$commit_message'"