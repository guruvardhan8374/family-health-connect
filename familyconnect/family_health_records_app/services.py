from django.utils import timezone
from datetime import timedelta
from django.db.models import Avg, Sum, Max
from .models import HealthRecord

def calculate_bmi(weight_kg, height_cm):
    """
    Calculates BMI based on weight (kg) and height (cm).
    """
    if not weight_kg or not height_cm or height_cm <= 0:
        return 0.0
    height_m = height_cm / 100.0
    return round(weight_kg / (height_m * height_m), 1)

def get_health_score(user):
    """
    Calculates a dynamic overall health score (0-100) based on recent health records.
    Scores metrics against ideal baseline health ranges.
    """
    recent_records = HealthRecord.objects.filter(user=user).order_by('-recorded_date')[:5]
    if not recent_records:
        return 70 # Default starting baseline score
        
    score_contributions = []
    
    for r in recent_records:
        day_score = 100
        # Heart rate check (Ideal: 60-100)
        if r.heart_rate > 0:
            if r.heart_rate < 50 or r.heart_rate > 120:
                day_score -= 20
            elif r.heart_rate < 60 or r.heart_rate > 100:
                day_score -= 10
                
        # Oxygen Level check (Ideal: 95-100)
        if r.oxygen_level > 0:
            if r.oxygen_level < 90:
                day_score -= 30
            elif r.oxygen_level < 95:
                day_score -= 15
                
        # Blood pressure check (Ideal: Systolic < 130, Diastolic < 85)
        if r.blood_pressure and "/" in r.blood_pressure:
            try:
                sys, dia = map(int, r.blood_pressure.split('/'))
                if sys > 140 or dia > 90:
                    day_score -= 20
                elif sys > 130 or dia > 85:
                    day_score -= 10
            except ValueError:
                pass
                
        # Steps check (Ideal: 8000+)
        if r.steps > 0:
            if r.steps < 4000:
                day_score -= 15
            elif r.steps < 8000:
                day_score -= 5
                
        score_contributions.append(day_score)
        
    return int(sum(score_contributions) / len(score_contributions))

def detect_anomalies(user):
    """
    Analyzes recent records to detect health anomalies or high risk vitals.
    """
    recent_records = HealthRecord.objects.filter(user=user).order_by('-recorded_date')[:3]
    anomalies = []
    
    for r in recent_records:
        # Check low oxygen
        if 0 < r.oxygen_level < 95:
            anomalies.append({
                "metric": "Oxygen Level",
                "value": r.oxygen_level,
                "recorded_date": r.recorded_date.isoformat(),
                "severity": "CRITICAL" if r.oxygen_level < 90 else "WARNING",
                "message": "Low blood oxygen levels detected."
            })
            
        # Check abnormal heart rate
        if r.heart_rate > 120 or (0 < r.heart_rate < 50):
            anomalies.append({
                "metric": "Heart Rate",
                "value": r.heart_rate,
                "recorded_date": r.recorded_date.isoformat(),
                "severity": "CRITICAL" if r.heart_rate > 140 or r.heart_rate < 40 else "WARNING",
                "message": "Tachycardia or Bradycardia condition detected."
            })
            
        # Check high blood pressure
        if r.blood_pressure and "/" in r.blood_pressure:
            try:
                sys, dia = map(int, r.blood_pressure.split('/'))
                if sys >= 140 or dia >= 90:
                    anomalies.append({
                        "metric": "Blood Pressure",
                        "value": r.blood_pressure,
                        "recorded_date": r.recorded_date.isoformat(),
                        "severity": "WARNING",
                        "message": "Hypertensive levels detected."
                    })
            except ValueError:
                pass
                
    return anomalies

from django.conf import settings
import google.generativeai as genai

def generate_health_suggestions(user):
    """
    Generates tailored AI/rule-based health recommendations and life tips.
    """
    recent_records = HealthRecord.objects.filter(user=user).order_by('-recorded_date')[:3]
    recent = recent_records.first()
    
    # Base fallback suggestions
    suggestions = [
        "Ensure you drink at least 2.5 liters of water daily for optimal organ performance.",
        "A consistent sleep schedule directly boosts your immune system and memory consolidation."
    ]
    
    if not recent:
        return suggestions
        
    # Check if Gemini API key is available
    if getattr(settings, 'GEMINI_API_KEY', ''):
        try:
            # Prepare context from recent logs
            context = []
            for r in recent_records:
                context.append(
                    f"Date: {r.recorded_date}\n"
                    f"- Heart Rate: {r.heart_rate} bpm\n"
                    f"- Oxygen: {r.oxygen_level}%\n"
                    f"- Blood Pressure: {r.blood_pressure or 'N/A'}\n"
                    f"- Steps: {r.steps}\n"
                    f"- Sleep: {r.sleep_hours} hrs\n"
                    f"- Water Intake: {r.water_intake} L\n"
                    f"- Weight/Height: {r.weight_kg} kg / {r.height_cm} cm\n"
                    f"- BMI: {r.bmi or 'N/A'}"
                )
            context_str = "\n---\n".join(context)
            
            prompt = (
                "You are an empathetic, professional AI family healthcare wellness assistant.\n"
                f"Here is the user's recent health log data:\n{context_str}\n\n"
                "Analyze this data and generate exactly 3 or 4 concise, highly personalized, actionable "
                "wellness suggestions, diet advice, or sleep/hydration tips. Do not provide medical diagnoses. "
                "Output each suggestion as a single plain-text line starting with a bullet (-). No header or extra intro text."
            )
            
            genai.configure(api_key=settings.GEMINI_API_KEY)
            model = genai.GenerativeModel('gemini-pro')
            response = model.generate_content(prompt)
            text = response.text.strip()
            
            # Parse lines starting with '-' or '*'
            ai_suggestions = []
            for line in text.split('\n'):
                line = line.strip()
                if not line:
                    continue
                if line.startswith('-') or line.startswith('*'):
                    line = line.lstrip('-*').strip()
                if line:
                    ai_suggestions.append(line)
                    
            if len(ai_suggestions) >= 2:
                return ai_suggestions
        except Exception as e:
            print(f"Gemini health suggestions error: {e}")

    # Fallback rule-based suggestions
    suggestions = []
    if recent.steps > 0 and recent.steps < 6000:
        suggestions.append("You walked less than 6,000 steps today. Try taking a brief 20-minute walk after dinner.")
    elif recent.steps > 10000:
        suggestions.append("Incredible job exceeding 10,000 steps today! Keep up this active lifestyle.")
        
    if recent.sleep_hours > 0 and recent.sleep_hours < 6.5:
        suggestions.append("Your sleep hours were lower than recommended. Focus on getting 7-8 hours tonight.")
        
    if recent.water_intake > 0 and recent.water_intake < 2.0:
        suggestions.append("Your water intake is low. Keep a water bottle handy and sip regularly.")
        
    if recent.bmi and recent.bmi > 25.0:
        suggestions.append("Your BMI indicates a slightly higher weight profile. Incorporate lean proteins and green vegetables in your diet.")
        
    if not suggestions:
        suggestions = [
            "Ensure you drink at least 2.5 liters of water daily for optimal organ performance.",
            "A consistent sleep schedule directly boosts your immune system and memory consolidation."
        ]
        
    return suggestions

def get_weekly_analytics(user):
    """
    Returns weekly aggregated averages/totals for dashboard chart views.
    """
    seven_days_ago = timezone.now().date() - timedelta(days=7)
    records = HealthRecord.objects.filter(user=user, recorded_date__gte=seven_days_ago)
    
    if not records.exists():
        return {
            "avg_heart_rate": 0, "avg_oxygen": 0, "total_steps": 0, 
            "avg_sleep": 0, "avg_water": 0, "total_calories": 0
        }
        
    agg = records.aggregate(
        avg_hr=Avg('heart_rate'),
        avg_o2=Avg('oxygen_level'),
        tot_steps=Sum('steps'),
        avg_sl=Avg('sleep_hours'),
        avg_wt=Avg('water_intake'),
        tot_cal=Sum('calories_burned')
    )
    
    return {
        "avg_heart_rate": round(agg['avg_hr'] or 0, 1),
        "avg_oxygen": round(agg['avg_o2'] or 0, 1),
        "total_steps": agg['tot_steps'] or 0,
        "avg_sleep": round(agg['avg_sl'] or 0, 1),
        "avg_water": round(agg['avg_wt'] or 0, 1),
        "total_calories": agg['tot_cal'] or 0
    }
