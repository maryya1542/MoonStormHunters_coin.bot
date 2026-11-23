 sqlite3
import asyncio
from aiogram import Bot, Dispatcher, types
from aiogram.filters import Command
from aiogram.types import Message

# --- НАСТРОЙКИ ---
TOKEN = 
ADMIN_ID = import sqlite3
import asyncio
from aiogram import Bot, Dispatcher, types
from aiogram.filters import Command
from aiogram.types import Message

# --- НАСТРОЙКИ ---
TOKEN = "9219772560:AAFDnZdOttK6qpJYtD1BP5rj_6UjYpyQsLA
"  
ADMIN_ID = 5407523412

bot = Bot(token=TOKEN)
dp = Dispatcher()

# --- БАЗА ДАННЫХ ---
def init_db():
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS users (
                        user_id INTEGER PRIMARY KEY,
                        username TEXT,
                        balance INTEGER DEFAULT 0
                    )''')
    conn.commit()
    conn.close()

def get_balance(user_id):
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT balance FROM users WHERE user_id = ?", (user_id,))
    res = cursor.fetchone()
    conn.close()
    return res[0] if res else 0

def update_balance(user_id, amount, username=None):
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    # Проверяем, есть ли юзер
    cursor.execute("SELECT user_id FROM users WHERE user_id = ?", (user_id,))
    if not cursor.fetchone():
        cursor.execute("INSERT INTO users (user_id, username, balance) VALUES (?, ?, ?)", (user_id, username, amount))
    else:
        cursor.execute("UPDATE users SET balance = balance + ? WHERE user_id = ?", (amount, user_id))
    conn.commit()
    conn.close()

# --- ХЕНДЛЕРЫ (КОМАНДЫ) ---

@dp.message(Command("start"))
async def start_cmd(message: Message):
    update_balance(message.from_user.id, 0, message.from_user.username) # Создаем счет, если нет
    await message.answer(f"Привет, {message.from_user.first_name}!\nТвой счет в клане создан. Проверь баланс командой /balance")

@dp.message(Command("balance"))
async def balance_cmd(message: Message):
    bal = get_balance(message.from_user.id)
    await message.answer(f"💳 Твой баланс: *{bal}* лунных камней", parse_mode="Markdown")

@dp.message(Command("pay"))
async def pay_cmd(message: Message):
    # Команда: /pay @username 100 (нужно ответить на сообщение пользователя или указать его @username)
    args = message.text.split()
    if len(args) < 3:
        await message.answer("Используй: /pay @username сумма")
        return
    
    target_username = args[1].replace("@", "")
    try:
        amount = int(args[2])
    except ValueError:
        await message.answer("Сумма должна быть числом.")
        return
    
    if amount <= 0:
        await message.answer("Сумма должна быть больше нуля.")
        return

    # Ищем юзера по username в базе
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT user_id FROM users WHERE username = ?", (target_username,))
    res = cursor.fetchone()
    conn.close()

    if not res:
        await message.answer("Такой пользователь не найден в базе. Пусть он сначала напишет /start.")
        return
    
    target_id = res[0]
    sender_bal = get_balance(message.from_user.id)

    if sender_bal < amount:
        await message.answer("Недостаточно средств на счету.")
        return

    # Перевод
    update_balance(message.from_user.id, -amount)
    update_balance(target_id, amount)
    
    await message.answer(f"✅ Перевод {amount} монет пользователю @{target_username} выполнен.")

@dp.message(Command("add"))
async def add_money_cmd(message: Message):
    # Только для админа
    if message.from_user.id != ADMIN_ID:
        await message.answer("У тебя нет прав на эту команду.")
        return
    
    args = message.text.split()
    if len(args) < 3:
        await message.answer("Используй: /add @username сумма")
        return

    target_username = args[1].replace("@", "")
    try:
        amount = int(args[2])
    except ValueError:
        await message.answer("Сумма должна быть числом.")
        return

    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT user_id FROM users WHERE username = ?", (target_username,))
    res = cursor.fetchone()
    conn.close()
    if not res:
        await message.answer("Пользователь не найден.")
        return
    
    update_balance(res[0], amount)
    await message.answer(f"👑 Админ начислил {amount} монет пользователю @{target_username}.")

# --- ЗАПУСК ---
async def main():
    init_db()
    print("Бот запущен...")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())  # Вставь свой Telegram ID (узнать можно у бота @userinfobot)

bot = Bot(token=TOKEN)
dp = Dispatcher()

# --- БАЗА ДАННЫХ ---
def init_db():
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS users (
                        user_id INTEGER PRIMARY KEY,
                        username TEXT,
                        balance INTEGER DEFAULT 0
                    )''')
    conn.commit()
    conn.close()

def get_balance(user_id):
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT balance FROM users WHERE user_id = ?", (user_id,))
    res = cursor.fetchone()
    conn.close()
    return res[0] if res else 0

def update_balance(user_id, amount, username=None):
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    # Проверяем, есть ли юзер
    cursor.execute("SELECT user_id FROM users WHERE user_id = ?", (user_id,))
    if not cursor.fetchone():
        cursor.execute("INSERT INTO users (user_id, username, balance) VALUES (?, ?, ?)", (user_id, username, amount))
    else:
        cursor.execute("UPDATE users SET balance = balance + ? WHERE user_id = ?", (amount, user_id))
    conn.commit()
    conn.close()

# --- ХЕНДЛЕРЫ (КОМАНДЫ) ---

@dp.message(Command("start"))
async def start_cmd(message: Message):
    update_balance(message.from_user.id, 0, message.from_user.username) # Создаем счет, если нет
    await message.answer(f"Привет, {message.from_user.first_name}!\nТвой счет в клане создан. Проверь баланс командой /balance")

@dp.message(Command("balance"))
async def balance_cmd(message: Message):
    bal = get_balance(message.from_user.id)
    await message.answer(f"💳 Твой баланс: *{bal}* клановых монет", parse_mode="Markdown")

@dp.message(Command("pay"))
async def pay_cmd(message: Message):
    # Команда: /pay @username 100 (нужно ответить на сообщение пользователя или указать его @username)
    args = message.text.split()
    if len(args) < 3:
        await message.answer("Используй: /pay @username сумма")
        return
    
    target_username = args[1].replace("@", "")
    try:
        amount = int(args[2])
    except ValueError:
        await message.answer("Сумма должна быть числом.")
        return
    
    if amount <= 0:
        await message.answer("Сумма должна быть больше нуля.")
        return

    # Ищем юзера по username в базе
    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT user_id FROM users WHERE username = ?", (target_username,))
    res = cursor.fetchone()
    conn.close()

    if not res:
        await message.answer("Такой пользователь не найден в базе. Пусть он сначала напишет /start.")
        return
    
    target_id = res[0]
    sender_bal = get_balance(message.from_user.id)

    if sender_bal < amount:
        await message.answer("Недостаточно средств на счету.")
        return

    # Перевод
    update_balance(message.from_user.id, -amount)
    update_balance(target_id, amount)
    
    await message.answer(f"✅ Перевод {amount} монет пользователю @{target_username} выполнен.")

@dp.message(Command("add"))
async def add_money_cmd(message: Message):
    # Только для админа
    if message.from_user.id != ADMIN_ID:
        await message.answer("У тебя нет прав на эту команду.")
        return
    
    args = message.text.split()
    if len(args) < 3:
        await message.answer("Используй: /add @username сумма")
        return

    target_username = args[1].replace("@", "")
    try:
        amount = int(args[2])
    except ValueError:
        await message.answer("Сумма должна быть числом.")
        return

    conn = sqlite3.connect('clan_economy.db')
    cursor = conn.cursor()
    cursor.execute("SELECT user_id FROM users WHERE username = ?", (target_username,))
    res = cursor.fetchone()
    conn.close()

    if not res:
        await message.answer("Пользователь не найден.")
        return
    
    update_balance(res[0], amount)
    await message.answer(f"👑 Админ начислил {amount} монет пользователю @{target_username}.")

# --- ЗАПУСК ---
async def main():
    init_db()
    print("Бот запущен...")
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
