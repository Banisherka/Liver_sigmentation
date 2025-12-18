# Команды Rails для проекта

## Важно!

Все команды Rails должны выполняться из папки `backend` и через `bundle exec`:

```powershell
cd D:\Projects\Liver_sigmentation\backend
```

## Основные команды

### Создание базы данных и миграции

```powershell
bundle exec rails db:create
bundle exec rails db:migrate
```

Или одной командой:
```powershell
bundle exec rails db:create db:migrate
```

### Запуск сервера

```powershell
bundle exec rails server
```

Или короткая версия:
```powershell
bundle exec rails s
```

### Rails консоль

```powershell
bundle exec rails console
```

Или короткая версия:
```powershell
bundle exec rails c
```

### Выполнение миграций

```powershell
bundle exec rails db:migrate
```

### Откат последней миграции

```powershell
bundle exec rails db:rollback
```

### Просмотр статуса миграций

```powershell
bundle exec rails db:migrate:status
```

## Почему bundle exec?

`bundle exec` гарантирует, что используются версии gem'ов, указанные в `Gemfile.lock`, а не глобально установленные версии. Это важно для согласованности зависимостей в проекте.

## Альтернатива

Если вы хотите использовать короткие команды без `bundle exec`, можно использовать `binstubs`:

```powershell
bundle binstubs --all
```

После этого можно использовать:
```powershell
bin/rails db:create
bin/rails db:migrate
bin/rails server
```

