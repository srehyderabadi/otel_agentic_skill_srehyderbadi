import logging
import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

# Setup logging with Hyderabadi flavor
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("biryani-service")

app = FastAPI(title="Biryani Service", description="The ultimate Hyderabadi Biryani provider")

@app.on_event("startup")
async def startup_event():
    logger.info("Arey ustad, Biryani deg chad gayi! (Service Started)")

@app.get("/health")
def health_check():
    return {"status": "Ek dum zabardast (Healthy)"}

@app.get("/biryani/{type}")
def get_biryani(type: str):
    biryani_menu = {
        "chicken": {"item": "Chicken Dum Biryani", "price": 250, "description": "Garam garam chicken biryani, double masala ustad!"},
        "mutton": {"item": "Mutton Biryani", "price": 350, "description": "Nalli gosht wala biryani, parda nikal ke khao!"},
        "veg": {"item": "Veg Biryani", "price": 180, "description": "Aloo aur paneer wala biryani, yeh toh pulao bolte ji, phir bhi lijiye!"}
    }
    
    if type.lower() not in biryani_menu:
        logger.error(f"Nakko miya, {type} kya hai yeh? Sirf chicken, mutton ya veg pucho!")
        raise HTTPException(status_code=404, detail="Kaisa aadmi hai yaaro? Aisa biryani nahi milta idhar! Sirf chicken, mutton, or veg pucho.")
        
    logger.info(f"Ek {type} biryani lara ustad!")
    return JSONResponse(status_code=200, content={
        "message": f"{type.capitalize()} Biryani tayyar hai!",
        "details": biryani_menu[type.lower()]
    })
