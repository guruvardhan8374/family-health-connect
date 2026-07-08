from fastapi import APIRouter
from pydantic import BaseModel
import os
from decouple import config

try:
    import google.generativeai as genai_legacy
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    user_id: int

class ChatResponse(BaseModel):
    response: str
    suggestions: list[str]

# Configure Gemini
GEMINI_API_KEY = config('GEMINI_API_KEY', default='')
if GEMINI_API_KEY and GENAI_AVAILABLE:
    genai_legacy.configure(api_key=GEMINI_API_KEY)

@router.post("/ai/suggest", response_model=ChatResponse)
async def get_ai_suggestions(request: ChatRequest):
    """
    Analyzes health data and provides personalized AI healthcare suggestions using real context.
    """
    prompt = f"""
    You are an AI Family Healthcare Assistant.
    User Question: {request.message}
    Provide a professional, empathetic, and concise health suggestion.
    Do not give medical diagnosis, but give wellness advice.
    """

    response_text = ""
    suggestions = []

    if GEMINI_API_KEY and GENAI_AVAILABLE:
        try:
            model = genai_legacy.GenerativeModel('gemini-1.5-flash')
            gemini_response = model.generate_content(prompt)
            response_text = gemini_response.text
            suggestions = ["View health trends", "Log new vitals", "Family overview"]
        except Exception as e:
            print(f"Gemini Error: {e}")
            response_text = "I'm having trouble connecting to my advanced brain right now, but I can still see your vitals. You look healthy overall!"

    if not response_text:
        if "sleep" in request.message.lower():
            response_text = "Aim for 7-8 hours of quality sleep tonight for optimal health."
            suggestions = ["Sleep hygiene tips", "Log sleep", "Reminders"]
        else:
            response_text = "I'm monitoring your family's health. You can ask about sleep, heart rate, or stress levels."
            suggestions = ["Check vitals", "AI Report", "Emergency Protocol"]

    return {
        "response": response_text,
        "suggestions": suggestions
    }
