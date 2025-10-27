#!/usr/bin/env python3
"""
강릉고등학교 총동문회 실제 데이터 임포트 (배치 처리 버전)
CSV 파일에서 동문 정보를 읽어 Firestore에 배치 업로드합니다.
"""

import csv
import re
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

def extract_graduation_year(nickname_or_label):
    """닉네임이나 라벨에서 졸업 기수 추출 (회차 숫자 그대로 반환)"""
    if not nickname_or_label:
        return None
    
    match = re.search(r'(\d+)회', str(nickname_or_label))
    if match:
        # 회차 숫자 그대로 반환 (1회 → 1, 25회 → 25)
        return int(match.group(1))
    
    return None

def clean_phone_number(phone):
    """전화번호 정리"""
    if not phone:
        return ""
    
    digits = re.sub(r'\D', '', phone)
    
    if digits.startswith('010') and len(digits) == 11:
        return f"{digits[:3]}-{digits[3:7]}-{digits[7:]}"
    
    return phone

def parse_csv_and_upload():
    """CSV 파일 파싱 및 Firestore 배치 업로드"""
    
    print("=" * 70)
    print("🏫 강릉고등학교 총동문회 실제 데이터 임포트 (고속 배치 처리)")
    print("=" * 70)
    
    # 기존 데이터 삭제
    print("\n🗑️  기존 데이터 삭제 중...")
    alumni_ref = db.collection('alumni')
    
    # 배치 삭제
    deleted = 0
    batch = db.batch()
    docs = alumni_ref.limit(500).stream()
    
    for doc in docs:
        batch.delete(doc.reference)
        deleted += 1
        if deleted % 500 == 0:
            batch.commit()
            batch = db.batch()
            print(f"  삭제 중... {deleted}개")
    
    if deleted % 500 != 0:
        batch.commit()
    
    print(f"✅ {deleted}개의 기존 데이터 삭제 완료")
    
    # CSV 파일 읽기 및 배치 업로드
    print("\n📂 CSV 파일 읽기 및 업로드 중...")
    csv_file = '/home/user/flutter_app/contacts.csv'
    
    uploaded_count = 0
    skipped_count = 0
    batch = db.batch()
    
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            try:
                # 이름
                first_name = row.get('First Name', '').strip()
                last_name = row.get('Last Name', '').strip()
                name = f"{first_name}{last_name}" if last_name else first_name
                
                if not name:
                    skipped_count += 1
                    continue
                
                # 전화번호
                phone_raw = row.get('Phone 1 - Value', '').strip()
                phone = clean_phone_number(phone_raw)
                
                if not phone or not phone.startswith('010'):
                    skipped_count += 1
                    continue
                
                # 졸업년도
                nickname = row.get('Nickname', '').strip()
                labels = row.get('Labels', '').strip()
                graduation_year = extract_graduation_year(nickname) or extract_graduation_year(labels) or 2000
                
                # 이메일, 직장, 주소
                email = row.get('E-mail 1 - Value', '').strip()
                company = row.get('Organization Name', '').strip() or '미등록'
                job_title = row.get('Organization Title', '').strip() or '미등록'
                
                address = row.get('Address 1 - Formatted', '').strip()
                if not address:
                    city = row.get('Address 1 - City', '').strip()
                    region = row.get('Address 1 - Region', '').strip()
                    if city or region:
                        address = f"{region} {city}".strip()
                
                notes = row.get('Notes', '').strip()
                bio = notes[:200] if notes else f"안녕하세요! {name}입니다."
                
                # 문서 데이터
                alumni_data = {
                    'name': name,
                    'phone': phone,
                    'graduation_year': graduation_year,
                    'email': email,
                    'company': company,
                    'job_title': job_title,
                    'address': address,
                    'birth_date': '',
                    'school_class': '',
                    'hobbies': '',
                    'bio': bio,
                    'profile_photo_url': '',
                    'is_verified': True,
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'updated_at': firestore.SERVER_TIMESTAMP,
                }
                
                doc_id = phone.replace('-', '')
                doc_ref = alumni_ref.document(doc_id)
                batch.set(doc_ref, alumni_data)
                
                uploaded_count += 1
                
                # 500개마다 배치 커밋 (Firestore 제한)
                if uploaded_count % 500 == 0:
                    batch.commit()
                    batch = db.batch()
                    print(f"📝 {uploaded_count}명 업로드 완료...")
                
            except Exception as e:
                skipped_count += 1
    
    # 마지막 배치 커밋
    if uploaded_count % 500 != 0:
        batch.commit()
    
    print(f"\n{'=' * 70}")
    print("✅ 데이터 임포트 완료!")
    print(f"{'=' * 70}")
    print(f"📊 업로드 성공: {uploaded_count}명")
    print(f"⏭️  스킵: {skipped_count}명")
    print(f"{'=' * 70}")

if __name__ == '__main__':
    try:
        parse_csv_and_upload()
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
