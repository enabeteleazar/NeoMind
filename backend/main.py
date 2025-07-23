from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="NeoMind API", version="1.0")

@app.get("/")
async def root():
    return {"message": "Jarvis NeoMind API is running."}

@app.get("/health")
async def health_check():
    return JSONResponse(content={"status": "ok"}, status_code=200)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
