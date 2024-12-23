// Derived from USPSTF Recommendation on Prediabetes and Type 2 Diabetes: Screening. Grade B recommendation.
// Available at:
// https://uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes
//
// Version 2.1.0 has no significant changes from version 2.0.0. Minor changes include:
// - Updated Notification and Recommendation text for improved readability
// - Updated dependency library CDSConnectCommonsForFHIRv401 to version 2.1.0
// - Updated dependency library USPSTFPrediabetesAndType2DiabetesSharedLogicFHIRv401 to version 1.1.0
//
// NOTE: This version has not been piloted in a clinical setting, but has undergone logic testing and review.

library USPSTFPrediabetesAndType2DiabetesPart1ScreeningFHIRv401 version '2.1.0'

// Data model
using FHIR version '4.0.1'

// External libraries
include FHIRHelpers version '4.0.1' called FHIRHelpers
include CDSConnectCommonsForFHIRv401 version '2.1.0' called C3F
include USPSTFPrediabetesAndType2DiabetesSharedLogicFHIRv401 version '1.1.0' called SharedLogic

// Code systems
codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'
codesystem "ICD-10-CM": 'http://hl7.org/fhir/sid/icd-10-cm'

// Value sets
valueset "Impaired Glucose Tolerance": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.85'
valueset "Fasting Plasma Glucose": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.87'
valueset "Prediabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1221.113'
valueset "Glucose Tolerance Test Results": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.94'

// Individual codes
code "HgA1C laboratory test": '4548-4' from "LOINC" display 'Hemoglobin A1c/​Hemoglobin.total in Blood'
code "Impaired fasting glucose ICD-10-CM code": 'R73.01' from "ICD-10-CM" display 'Impaired fasting glucose'
code "Impaired fasting glucose SNOMED-CT code": '390951007' from "SNOMED-CT" display 'Impaired fasting glycaemia (disorder)'
code "Impaired glucose tolerance ICD-10-CM code": 'R73.02' from "ICD-10-CM" display 'Impaired glucose tolerance (oral)'

// Concepts for aggregating codes
concept "Impaired Fasting Glucose (IFG)": { "Impaired fasting glucose ICD-10-CM code", "Impaired fasting glucose SNOMED-CT code" } display 'Impaired fasting glucose'

context Patient

// Inclusions provided by shared logic module

// Exclusions

// Observations must have one of the following populated, otherwise "ObservationLookBack"() will filter out:
// effectiveDateTime, effectivePeriod, issued

define "RecentA1cOrGlucoseTests":
  C3F."Verified"(C3F."ObservationLookBack"(
    ["Observation": "Fasting Plasma Glucose"] union
    ["Observation": "Glucose Tolerance Test Results"] union
    ["Observation": "HgA1C laboratory test"], 3 years))

define "HasHadRecentA1cOrGlucoseTests":
  exists "RecentA1cOrGlucoseTests"

// Conditions must have one of the following populated, otherwise "ConditionLookBack"() will filter out:
// onsetDateTime, onsetPeriod, dateRecorded
define "HasPrediabetes":
  exists C3F."Confirmed"(C3F."ActiveOrRecurring"(C3F."ConditionLookBack"(["Condition": "Prediabetes"], 12 months)))

define "HasImpairedFastingGlucose":
  exists C3F."Confirmed"(C3F."ActiveOrRecurring"(C3F."ConditionLookBack"(["Condition": "Impaired Fasting Glucose (IFG)"], 12 months)))

define "HasImpairedGlucoseTolerance":
  exists C3F."Confirmed"(C3F."ActiveOrRecurring"(C3F."ConditionLookBack"(
    ["Condition": "Impaired glucose tolerance ICD-10-CM code"] union
    ["Condition": "Impaired Glucose Tolerance"], 12 months)))

define "Excluded":
  SharedLogic."IsPregnant" or
  "HasHadRecentA1cOrGlucoseTests" or
  "HasPrediabetes" or
  SharedLogic."HasDiabetes" or
  "HasImpairedFastingGlucose" or
  "HasImpairedGlucoseTolerance"

define "InPopulation":
  SharedLogic."MeetsPartOneInclusionLogic" and not "Excluded"

define "Notification":
  if "InPopulation" then
'You may be at risk for (in other words, more likely to get) prediabetes and type 2 diabetes based on risk factors you may have.

Many factors increase a person’s risk for high blood sugar including: being 35 years or older; being overweight or obese; having a parent, brother or sister with diabetes; or if you are a woman with a history of  diabetes while pregnant (gestational diabetes) or polycystic ovarian syndrome (a condition where the ovaries produce higher-than-normal amounts of certain hormones). If you are African-American, Hispanic, Alaskan Native, American Indian, Asian American, or Native Hawaiian/Pacific Islander you may also be more likely to have high blood sugar.'
  else
    null

define "Recommendation":
  if "InPopulation" then
'Experts (i.e., The U.S. Preventive Services Task Force) recommend blood tests to measure blood sugar levels if you are at increased risk. If the tests show you have high blood sugar (prediabetes), there are steps you can take to help lower your blood sugar and prevent diabetes.

Contact your doctor to schedule an appointment and ask about being tested for high blood sugar and diabetes.

Here are some links to resources you may want to review:

* [Prediabetes: Your chance to prevent Type 2 diabetes](https://www.cdc.gov/diabetes/basics/prediabetes.html)
* [Take steps to prevent type 2 diabetes](https://healthfinder.gov/HealthTopics/Category/health-conditions-and-diseases/diabetes/take-steps-to-prevent-type-2-diabetes)
* [The U.S. Preventive Services Task Force Recommendation on “Prediabetes and Type 2 Diabetes: Screening”](https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes)'
  else
    null

define "Information":
  (List{
    if not exists (SharedLogic."RaceCodes") then
      'INFORMATION: No race information available.'
    else null,
    if SharedLogic."EthnicityCode" is not null and not SharedLogic."IsHispanicOrLatino" then
      'INFORMATION: Non-Hispanic or Latino ethnicity recorded.'
    else null,
    if SharedLogic."MostRecentBodyMassIndexMeasurement" is null then
      'INFORMATION: No recent body mass index measurement available.'
    else null,
    if "RecentA1cOrGlucoseTests" is null then
      'INFORMATION: No recent A1c or glucose lab tests available.'
    else null
  }) Info where Info is not null