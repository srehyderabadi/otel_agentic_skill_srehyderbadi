import logging
import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

# Setup logging with Hyderabadi flavor
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("chai-service")

app = FastAPI(title="Chai Service", description="Chai bina chain kaha re miya!")

@app.on_event("startup")
async def startup_event():
    logger.info("Chai ubal rahi hai! (Service Started)")

@app.get("/health")
def health_check():
    return {"status": "Ek dum zabardast (Healthy)"}

@app.get("/chai/{type}")
def get_chai(type: str):
    chai_menu = {
        "irani": {"item": "Irani Chai", "price": 20, "description": "Ek dum kadak irani chai, osmania biscuit ke saath!"},
        "lemon": {"item": "Lemon Chai", "price": 15, "description": "Garam garam nimbu chai!"},
        "masala": {"item": "Masala Chai", "price": 25, "description": "Adrak aur elaichi maza dila denge!"}
    }
    
    if type.lower() not in chai_menu:
        logger.error(f"Kya miya, {type} chai puchre tum? Coffee shop samjhe kya isko?")
        raise HTTPException(status_code=404, detail="Sirf Irani, Lemon, ya Masala chai milengi idhar!")
        
    logger.info(f"Ek {type} chai lau kya re chotu!")
    return JSONResponse(status_code=200, content={
        "message": f"{type.capitalize()} Chai tayyar hai miya!",
        "details": chai_menu[type.lower()]
    })
