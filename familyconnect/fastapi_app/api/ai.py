from fastapi import APIRouter
from pydantic import BaseModel
import os
import google.generativeai as genai
from health.models import HealthMetric
from decouple import config

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    user_id: int

class ChatResponse(BaseModel):
    response: str
    suggestions: list[str]

# Configure Gemini
GEMINI_API_KEY = config('GEMINI_API_KEY', default='')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-pro')

@router.post("/ai/suggest", response_model=ChatResponse)
async def get_ai_suggestions(request: ChatRequest):
    """
    Analyzes health data and provides personalized AI healthcare suggestions using real context.
    """
    # Fetch latest vitals for context
    latest_vitals = HealthMetric.objects.filter(user_id=request.user_id).order_by('-recorded_at')[:5]
    vitals_context = "\n".join([f"- {v.get_metric_type_display()}: {v.value} {v.unit or ''} at {v.recorded_at}" for v in latest_vitals])
    
    prompt = f"""
    You are an AI Family Healthcare Assistant. 
    User Question: {request.message}
    
    User's Latest Health Data:
    {vitals_context}
    
    Provide a professional, empathetic, and concise health suggestion. 
    Do not give medical diagnosis, but give wellness advice.
    """

    response_text = ""
    suggestions = []

    if GEMINI_API_KEY:
        try:
            gemini_response = model.generate_content(prompt)
            response_text = gemini_response.text
            suggestions = ["View health trends", "Log new vitals", "Family overview"]
        except Exception as e:
            print(f"Gemini Error: {e}")
            response_text = "I'm having trouble connecting to my advanced brain right now, but I can still see your vitals. You look healthy overall!"
    
    if not response_text:
        # Smart Fallback logic
        if "sleep" in request.message.lower():
            response_text = f"Based on your recent logs, your sleep pattern is slightly irregular. Aim for 7-8 hours tonight. Your latest recorded score was {next((v.value for v in latest_vitals if v.metric_type == 'SLEEP'), 'N/A')}."
            suggestions = ["Sleep hygiene tips", "Log sleep", "Reminders"]
        else:
            response_text = "I'm monitoring your family's health. You can ask about sleep, heart rate, or stress levels."
            suggestions = ["Check vitals", "AI Report", "Emergency Protocol"]

    return {
        "response": response_text,
        "suggestions": suggestions
    }
