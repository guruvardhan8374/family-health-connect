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

def generate_health_suggestions(user):
    """
    Returns rule-based health recommendations based on the user's latest records.
    """
    recent_records = HealthRecord.objects.filter(user=user).order_by('-recorded_date')[:3]
    recent = recent_records.first()

    if not recent:
        return [
            "Drink at least 2.5 litres of water daily for optimal organ function.",
            "A consistent sleep schedule boosts your immune system and memory.",
        ]

    suggestions = []

    if recent.steps > 0 and recent.steps < 6000:
        suggestions.append("You walked fewer than 6,000 steps. Try a 20-minute walk after dinner.")
    elif recent.steps > 10000:
        suggestions.append("Great job exceeding 10,000 steps today! Keep up this active lifestyle.")

    if recent.sleep_hours > 0 and recent.sleep_hours < 6.5:
        suggestions.append("Your sleep was below recommended levels. Aim for 7-8 hours tonight.")

    if recent.water_intake > 0 and recent.water_intake < 2.0:
        suggestions.append("Your water intake is low. Keep a water bottle handy and sip regularly.")

    if recent.bmi and recent.bmi > 25.0:
        suggestions.append("Your BMI is slightly elevated. Include lean proteins and vegetables in your meals.")

    if not suggestions:
        suggestions = [
            "Drink at least 2.5 litres of water daily for optimal organ function.",
            "A consistent sleep schedule boosts your immune system and memory.",
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
