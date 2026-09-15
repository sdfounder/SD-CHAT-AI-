import asyncio
import asyncpg
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres.ryvmacsmfvllhgbqbnkb:sekoudiaby224@aws-1-eu-west-1.pooler.supabase.com:5432/postgres"
)

async def apply_migration():
    print(f"Connecting to database...")
    conn = await asyncpg.connect(DATABASE_URL)
    print("Connected successfully!")
    
    migration_file = os.path.join(os.path.dirname(__file__), "../database/migrations/01_sd_chat_ai_schema.sql")
    with open(migration_file, "r") as f:
        sql = f.read()
    
    print(f"Executing migration {migration_file}...")
    try:
        await conn.execute(sql)
        print("Migration executed successfully!")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(apply_migration())
