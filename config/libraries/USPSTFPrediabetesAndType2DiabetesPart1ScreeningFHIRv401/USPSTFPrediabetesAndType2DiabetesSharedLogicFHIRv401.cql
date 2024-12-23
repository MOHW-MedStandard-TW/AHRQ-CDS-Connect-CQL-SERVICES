// Derived from USPSTF Recommendation on Prediabetes and Type 2 Diabetes: Screening. Grade B recommendation.
// Available at:
// https://uspreventiveservicestaskforce.org/uspstf/recommendation/screening-for-prediabetes-and-type-2-diabetes
//
// Version 1.1.0 has no significant changes from version 1.0.0. Minor changes include:
// - Updated dependency library CDSConnectCommonsForFHIRv401 to version 2.1.0
//
// This CDS is meant to be used in conjunction with one of the following CQL libraries
//  - USPSTFPrediabetesAndType2DiabetesPart1ScreeningFHIRv401
//  - USPSTFPrediabetesAndType2DiabetesPart2CounselingFHIRv401
//
// NOTE: The R4 port of this artifact has not been piloted in a clinical setting, but has undergone logic testing and review.
library USPSTFPrediabetesAndType2DiabetesSharedLogicFHIRv401 version '1.1.0'

// Data model
using FHIR version '4.0.1'

// External libraries
include FHIRHelpers version '4.0.1' called FHIRHelpers
include CDSConnectCommonsForFHIRv401 version '2.1.0' called C3F

// Code systems
codesystem "ICD-9-CM": 'http://hl7.org/fhir/sid/icd-9-cm'
codesystem "ICD-10-CM": 'http://hl7.org/fhir/sid/icd-10-cm'
codesystem "LOINC": 'http://loinc.org'
codesystem "Race & Ethnicity - CDC": 'urn:oid:2.16.840.1.113883.6.238'
codesystem "SNOMED-CT": 'http://snomed.info/sct'

// Value sets
valueset "First Degree Family Member": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.92'
valueset "Diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.103.12.1001'
valueset "Gestational diabetes": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.90'
valueset "Polycystic Ovary Syndrome": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.151'
valueset "CDS Pregnancy": 'https://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.264'

// Individual codes
code "Black or African American": '2054-5' from "Race & Ethnicity - CDC" display 'Black or African American'
code "American Indian or Alaska Native": '1002-5' from "Race & Ethnicity - CDC" display 'American Indian or Alaska Native'
code "Native Hawaiian or Other Pacific Islander": '2076-8' from "Race & Ethnicity - CDC" display 'Native Hawaiian or Other Pacific Islander'
code "Asian": '2028-9' from "Race & Ethnicity - CDC" display 'Asian'
code "Hispanic or Latino": '2135-2' from "Race & Ethnicity - CDC" display 'Hispanic or Latino'
code "Body mass index": '39156-5' from "LOINC" display 'Body mass index (BMI) [Ratio]'
code "Polycystic ovarian syndrome code": 'E28.2' from "ICD-10-CM"display 'Polycystic ovarian syndrome'
code "Polycystic ovaries code": '256.4' from "ICD-9-CM" display 'Polycystic ovaries'
code "Pregnancy status": '82810-3' from "LOINC" display 'Pregnancy status'
code "Pregnant": '77386006' from "SNOMED-CT" display 'Patient currently pregnant (finding)'

// Concepts for aggregating codes
concept "Polycystic ovarian syndrome": { "Polycystic ovarian syndrome code", "Polycystic ovaries code" } display 'Polycystic ovarian syndrome'

context Patient

// Part One Inclusions

// RaceExtension: Using US Core Race extension as specfied in the US Core Patient profile.
// Note that US Core allows only a single race extension.
// <http://www.hl7.org/fhir/us/core/StructureDefinition-us-core-race.html>
// <http://www.hl7.org/fhir/us/core/StructureDefinition-us-core-patient.html>
define "RaceExtension":
	singleton from (
		Patient.extension Extension
		where Extension.url.value = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
	)

// RaceCodes: Within the US Core Race Extension, up to five races may be simultaneously listed
// using ombCategory sub-extensions. This expression finds them and returns their Coding values.
define "RaceCodes":
	("RaceExtension".extension) Extension where Extension.url.value = 'ombCategory' return FHIRHelpers.ToCode(Extension.value as FHIR."Coding")

// EthnicityExtension: Using US Core Ethnicity extension as specfied in the US Core Patient profile.
// Note that US Core allows only a single ethnicity extension.
// <http://www.hl7.org/fhir/us/core/StructureDefinition-us-core-ethnicity.html>
// <http://www.hl7.org/fhir/us/core/StructureDefinition-us-core-patient.html>
define "EthnicityExtension":
	singleton from (
		Patient.extension Extension
		where Extension.url.value = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
	)

// EthnicityCode: Within the US Core Ethnicity Extension, the ombCategory sub-extension allows only a single value,
// while the "detailed" extensions allow multiple values. We only need the single ombCategory since that indicates
// whether or not the patient is Hispanic or Latino. This expression returns that ethnicity code.
define "EthnicityCode":
	singleton from (
    ("EthnicityExtension".extension) Extension where Extension.url.value = 'ombCategory' return FHIRHelpers.ToCode(Extension.value as FHIR."Coding")
  )

define "IsAfricanAmerican": if exists ("RaceCodes") then exists ("RaceCodes" Race where Race ~ "Black or African American") else null
define "IsAmericanIndianOrAlaskaNative": if exists ("RaceCodes") then exists ("RaceCodes" Race where Race ~ "American Indian or Alaska Native") else null
define "IsNativeHawaiianOrOtherPacificIslander": if exists ("RaceCodes") then exists ("RaceCodes" Race where Race ~ "Native Hawaiian or Other Pacific Islander") else null
define "IsAsian": if exists ("RaceCodes") then exists ("RaceCodes" Race where Race ~ "Asian") else null
define "IsHispanicOrLatino": if "EthnicityCode" is not null then "EthnicityCode" ~ "Hispanic or Latino" else null

// Note no lookback
define "MostRecentBodyMassIndexMeasurement":
  C3F."MostRecent"(C3F."Verified"(["Observation": "Body mass index"]))

define "MostRecentBodyMassIndexValue":
  C3F."QuantityValue"("MostRecentBodyMassIndexMeasurement")

define "PatientAgeInYears":
  AgeInYears()

define "IsOverweight":
  "MostRecentBodyMassIndexValue" >= 25 'kg/m2'

define "IsOverweightAsianThreshold":
  "MostRecentBodyMassIndexValue" >= 23 'kg/m2'

define "HasFamilyHistoryOfDiabetes":
  exists
    (["FamilyMemberHistory": relationship in "First Degree Family Member"]) History
    where History.condition.code in "Diabetes"

define "HasPolycysticOvarySyndrome":
  exists C3F."Confirmed"(
    ["Condition": "Polycystic Ovary Syndrome"]
    union ["Condition": "Polycystic ovarian syndrome"]
  )

define "HasOtherRiskFactors":
  "HasFamilyHistoryOfDiabetes" or
  "HasPolycysticOvarySyndrome" or
  "IsAfricanAmerican" or
  "IsAmericanIndianOrAlaskaNative" or
  "IsNativeHawaiianOrOtherPacificIslander" or
  "IsHispanicOrLatino"

// No lookback
define "HadGestationalDiabetes":
  exists C3F."Confirmed"(["Condition": "Gestational diabetes"])

define "MeetsPartOneInclusionLogic":
  ("PatientAgeInYears" >= 35 and "PatientAgeInYears" <= 70 and "IsOverweight") or
  ("PatientAgeInYears" >= 18 and "PatientAgeInYears" < 35 and "IsOverweight" and "HasOtherRiskFactors") or
  ("PatientAgeInYears" >= 18 and "PatientAgeInYears" <= 70 and "IsOverweightAsianThreshold" and "IsAsian") or
  ("PatientAgeInYears" >= 18 and "PatientAgeInYears" <= 70 and "HadGestationalDiabetes")

// Other Shared Logic Expressions

// Conditions must have one of the following populated, otherwise "ConditionLookBack"() will filter out:
// onsetDateTime, onsetPeriod, dateRecorded
define "HasDiabetes":
  exists C3F."Confirmed"(C3F."ActiveOrRecurring"(C3F."ConditionLookBack"(["Condition": "Diabetes"], 12 months)))

// Observations must have one of the following populated, otherwise "ObservationLookBack"() will filter out:
// effectiveDateTime, effectivePeriod, issued
define "MostRecentPregnancyObservation":
  C3F."MostRecent"(C3F."Verified"(C3F."ObservationLookBack"(["Observation": "Pregnancy status"], 42 weeks)))

define "IsPregnant":
  exists C3F."Confirmed"(C3F."ActiveCondition"(
    ["Condition": "CDS Pregnancy"] ))
  or C3F."ConceptValue"("MostRecentPregnancyObservation") ~ "Pregnant"

