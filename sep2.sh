#!/bin/bash
set -e  # Прерывать при ошибках

# Настройка Git для автоматического режима
export GIT_MERGE_AUTOEDIT=no
git config core.autocrlf false

# Функция для безопасного переключения веток
safe_checkout() {
    git reset --hard HEAD --quiet
    git clean -fd --quiet
    git checkout "$1" --force --quiet
}

git pull --quiet
safe_checkout "storage_1c"
git pull --quiet
safe_checkout "branch_sync_hran"

logof=$(git log --reverse storage_1c...branch_sync_hran --pretty=format:"%h;%s|" | tr -d '\r\n')
IFS='|' read -ra my_array <<< "$logof"

echo "!! Начало обработки коммитов"
for i in "${my_array[@]}"; do
    BranchName=$(echo "$i" | sed 's/.*;//')
    commit=$(echo "$i" | sed 's/;.*//')
    echo "!! Обработка: ${BranchName} (коммит ${commit})"
    
    # Всегда начинаем с чистого состояния
    safe_checkout "develop"
    
    # Создаем feature-ветку
    if git show-ref --verify --quiet refs/remotes/origin/"feature/${BranchName}"; then
        safe_checkout "feature/${BranchName}"
        # Устанавливаем upstream перед pull
        git branch --set-upstream-to=origin/"feature/${BranchName}" "feature/${BranchName}" --quiet
        git pull --quiet
    else
        git checkout -b "feature/${BranchName}" develop --quiet
        # Сначала делаем коммит пустых изменений
        git commit --allow-empty -m "Initial commit for ${BranchName}" --quiet
        # Устанавливаем upstream при первом push
        git push --set-upstream origin "feature/${BranchName}" --quiet
    fi
    
    # Cherry-pick с обработкой ошибок
    set +e  # Временно отключаем прерывание при ошибках
    git cherry-pick "${commit}" --keep-redundant-commits --strategy-option recursive -X theirs --no-edit >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        # Автоматическое разрешение конфликтов
        git diff --name-only --diff-filter=U | while read -r file; do
            [ "$file" != "src/cf/VERSION" ] && git checkout --theirs "$file" 2>/dev/null
            git add "$file" 2>/dev/null
        done
        
        # Продолжаем cherry-pick
        git cherry-pick --continue --no-edit >/dev/null 2>&1 || true
    fi
    set -e  # Включаем обработку ошибок обратно
    
    # Гарантированно убираем VERSION
    git rm --cached src/cf/VERSION 2>/dev/null || true
    git reset -- src/cf/VERSION 2>/dev/null || true
    
    # Коммит изменений
    git add . -- ':!src/cf/VERSION'
    git commit --allow-empty -m "feature/${BranchName} - ${commit}" --quiet
    
    # Удаляем dumplist.txt если существует
    [ -f "src/cf/dumplist.txt" ] && git rm -f "src/cf/dumplist.txt" --quiet
    
    # Пушим изменения
    git push origin "feature/${BranchName}" --force-with-lease --quiet
done

# Финализация
safe_checkout "branch_sync_hran"
git merge "storage_1c" --no-edit --quiet
git push origin "branch_sync_hran" --quiet
safe_checkout "storage_1c"