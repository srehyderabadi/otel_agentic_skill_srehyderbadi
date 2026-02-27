import logging
import os
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

# Setup logging with Hyderabadi flavor
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("order-service")

app = FastAPI(title="Order Service", description="The main entry point for all your Hyderabadi cravings")

BIRYANI_SERVICE_URL = os.getenv("BIRYANI_SERVICE_URL", "http://localhost:8001")
CHAI_SERVICE_URL = os.getenv("CHAI_SERVICE_URL", "http://localhost:8002")

@app.on_event("startup")
async def startup_event():
    logger.info("Dukaan khul gayi ustad! Order Service is ready. Bismillah!")

@app.get("/health")
def health_check():
    return {"status": "Ek dum zabardast (Healthy)"}

@app.get("/order/{category}/{item_type}")
async def place_order(category: str, item_type: str):
    category = category.lower()
    
    if category in ["pizza", "pasta", "coffee"]:
        logger.error(f"Ustad kahan se aye ki tum log? {category} mangre apne dhabe pe!")
        return JSONResponse(
            status_code=500,
            content={"error": f"Kaha miya, {category} nakko yaha! Sidha biryani ya chai pucho ji, nahi toh rasta naapo!"}
        )
        
    if category == "biryani":
        logger.info(f"Order aaya re bhai, ek {item_type} biryani la!")
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(f"{BIRYANI_SERVICE_URL}/biryani/{item_type}")
                if response.status_code == 200:
                    return response.json()
                else:
                    raise HTTPException(status_code=response.status_code, detail=response.json().get('detail', 'Kuch toh gadbad hai miya biryani service me!'))
            except httpx.RequestError as exc:
                logger.error(f"Biryani service pakda nahi jaara! {exc}")
                raise HTTPException(status_code=503, detail="Arey ustad, biryani wale bhaiya gayab hai, thodi der me aao!")

    elif category == "chai":
        logger.info(f"Order aaya ji, ek {item_type} chai banau!")
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(f"{CHAI_SERVICE_URL}/chai/{item_type}")
                if response.status_code == 200:
                    return response.json()
                else:
                    raise HTTPException(status_code=response.status_code, detail=response.json().get('detail', 'Chai ki patti khatam ho gayi kya re?'))
            except httpx.RequestError as exc:
                logger.error(f"Chai service nahi chalra! {exc}")
                raise HTTPException(status_code=503, detail="Chotu chutti pe hai, chai nahi ban sakti abhi!")
                
    else:
        logger.error(f"Ajeeb item maangre {category}, na biryani na chai!")
        raise HTTPException(status_code=400, detail=f"{category} kya hota hai ji? Hyderabad aaye toh biryani ya chai chakhna, bas!")
