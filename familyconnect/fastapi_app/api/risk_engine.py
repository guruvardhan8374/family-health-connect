import numpy as np

class MedicalRiskEngine:
    @staticmethod
    def calculate_heart_risk(vitals):
        """
        Simplified ML-based heart risk scoring.
        In production, this would use a pre-trained XGBoost or TensorFlow model.
        """
        # vitals: list of HealthMetric values (HEART_RATE, BLOOD_PRESSURE, etc.)
        hr_values = [v.value for v in vitals if v.metric_type == 'HEART_RATE']
        bp_values = [v.value for v in vitals if v.metric_type == 'BLOOD_PRESSURE']
        
        if not hr_values: return 0
        
        avg_hr = np.mean(hr_values)
        variability = np.std(hr_values)
        
        # Risk factors: High average HR, High variability, High BP
        risk_score = (avg_hr / 100) * 0.4 + (variability / 20) * 0.3
        if bp_values:
            risk_score += (np.mean(bp_values) / 140) * 0.3
            
        return min(round(risk_score * 100, 1), 100.0)

    @staticmethod
    def detect_sleep_apnea_risk(sleep_vitals):
        """
        Analyzes oxygen levels and sleep scores to detect potential sleep disorders.
        """
        oxygen_levels = [v.value for v in sleep_vitals if v.metric_type == 'OXYGEN']
        if not oxygen_levels: return "INSUFFICIENT_DATA"
        
        drops = [o for o in oxygen_levels if o < 90]
        if len(drops) > 3:
            return "HIGH_RISK"
        elif len(drops) > 0:
            return "MODERATE_RISK"
        return "LOW_RISK"
