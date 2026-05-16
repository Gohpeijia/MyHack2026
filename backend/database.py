import os
import asyncio
import libsql_client
from dotenv import load_dotenv

load_dotenv()

url = os.getenv("TURSO_DATABASE_URL")
auth_token = os.getenv("TURSO_AUTH_TOKEN")

async def connect_db():
    try:
        # Initialize the Turso connection
        client = libsql_client.create_client(url=url, auth_token=auth_token)
        print("✅ Successfully connected to Turso!")
        
        # Run a test query
        result = await client.execute("SELECT 1;")
        print("Query result:", result.rows)
        
    except Exception as e:
        print(f"❌ Turso connection failed: {e}")
    finally:
        if 'client' in locals():
            await client.close()

# Run the async function
asyncio.run(connect_db())