#!/usr/bin/env python3
"""
CSV 데이터를 Firestore에 모든 필드 포함하여 업로드
"""
import firebase_admin
from firebase_admin import credentials, firestore
import csv
import re
from datetime import datetime

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def extract_graduation_year(nickname, labels):
    """닉네임이나 라벨에서 회차 정보 추출 (예: 21회 -> 2021)"""
    text = f"{nickname} {labels}"
    
    # "21회" 형태 찾기
    match = re.search(r'(\d{1,2})회', text)
    if match:
        year_suffix = int(match.group(1))
        # 50 이상이면 1900년대, 미만이면 2000년대로 가정
        if year_suffix >= 50:
            return 1900 + year_suffix
        else:
            return 2000 + year_suffix
    
    return 2000  # 기본값

def clean_phone(phone):
    """전화번호에서 하이픈 제거"""
    return phone.replace('-', '').replace(' ', '').strip()

def import_csv_to_firestore():
    """CSV 파일을 읽어서 Firestore에 업로드"""
    
    print("=" * 80)
    print("📊 CSV → Firestore 전체 필드 업로드 시작")
    print("=" * 80)
    
    # Firestore 배치 설정
    batch = db.batch()
    batch_count = 0
    batch_size = 500  # Firestore 배치 제한
    
    uploaded_count = 0
    skipped_count = 0
    error_count = 0
    
    with open('contacts.csv', 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for idx, row in enumerate(reader, 1):
            try:
                # 필수 필드 확인
                name = row.get('First Name', '').strip()
                phone = clean_phone(row.get('Phone 1 - Value', ''))
                
                # 필터링 조건
                if not name:
                    skipped_count += 1
                    continue
                
                if not phone or not phone.startswith('010'):
                    skipped_count += 1
                    continue
                
                # 회차 정보 추출
                nickname = row.get('Name Suffix', '').strip()
                labels = row.get('Labels', '').strip()
                graduation_year = extract_graduation_year(nickname, labels)
                
                # 모든 필드 수집
                alumni_data = {
                    'phone': phone,
                    'name': name,
                    'graduation_year': graduation_year,
                    'email': row.get('E-mail 1 - Value', '').strip(),
                    'email2': row.get('E-mail 2 - Value', '').strip(),
                    'company': row.get('Organization Name', '').strip(),
                    'job_title': row.get('Organization Title', '').strip(),
                    'department': row.get('Organization Department', '').strip(),
                    'address': row.get('Address 1 - Formatted', '').strip(),
                    'address2': row.get('Address 2 - Formatted', '').strip(),
                    'birth_date': row.get('Birthday', '').strip(),
                    'notes': row.get('Notes', '').strip(),
                    'phone2': clean_phone(row.get('Phone 2 - Value', '')),
                    'profile_photo_url': '',
                    'is_verified': False,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'updated_at': firestore.SERVER_TIMESTAMP,
                }
                
                # Firestore 문서 ID로 전화번호 사용
                doc_ref = db.collection('alumni').document(phone)
                batch.set(doc_ref, alumni_data, merge=True)
                batch_count += 1
                uploaded_count += 1
                
                # 배치 커밋
                if batch_count >= batch_size:
                    batch.commit()
                    print(f"✅ 배치 커밋: {uploaded_count}명 업로드 완료")
                    batch = db.batch()
                    batch_count = 0
                
                # 진행상황 표시
                if idx % 1000 == 0:
                    print(f"📊 진행중: {idx}행 처리 완료 (업로드: {uploaded_count}, 제외: {skipped_count})")
                
            except Exception as e:
                error_count += 1
                print(f"❌ 오류 발생 (행 {idx}): {e}")
    
    # 마지막 배치 커밋
    if batch_count > 0:
        batch.commit()
        print(f"✅ 마지막 배치 커밋: 총 {uploaded_count}명 업로드 완료")
    
    # 결과 요약
    print("\n" + "=" * 80)
    print("📊 업로드 완료 요약")
    print("=" * 80)
    print(f"✅ 업로드 성공: {uploaded_count}명")
    print(f"⚠️  제외됨: {skipped_count}명 (이름 없음 또는 비010 번호)")
    print(f"❌ 오류: {error_count}건")
    print(f"📋 총 처리: {uploaded_count + skipped_count}행")
    print("\n포함된 필드:")
    print("  - 기본 정보: 이름, 전화번호, 기수")
    print("  - 이메일: email, email2")
    print("  - 직장 정보: company, job_title, department")
    print("  - 주소: address, address2")
    print("  - 기타: birth_date, notes, phone2")
    print("=" * 80)

if __name__ == '__main__':
    import_csv_to_firestore()
