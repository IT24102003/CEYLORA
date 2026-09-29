from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="CEYLORA Agentic AI Service")

class HealthResponse(BaseModel):
    status: str
    service: str

@app.get("/health", response_model=HealthResponse)
def health_check():
    return HealthResponse(status="ok", service="CEYLORA Agentic AI")

@app.get("/")
def root():
    return {"message": "CEYLORA Agentic AI Service is running"}