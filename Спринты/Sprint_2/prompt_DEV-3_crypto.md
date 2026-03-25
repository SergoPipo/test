---
sprint: 2
agent: DEV-3
role: Security (SEC) — CryptoService
wave: 1
depends_on: []
---

# Роль

Ты — специалист по безопасности. Реализуй CryptoService для шифрования API-ключей брокера с использованием AES-256-GCM.

# Предварительная проверка (ВЫПОЛНИ ПЕРВЫМ ДЕЛОМ)

```
1. Python >= 3.11 (python3 --version)
2. Файл backend/app/common/crypto.py существует (содержит стаб)
3. Пакет cryptography в зависимостях pyproject.toml (уже есть: "cryptography>=42.0")
4. Файл backend/app/config.py содержит ENCRYPTION_KEY
5. pytest tests/ проходит на develop (0 failures)
```

**Если что-то не найдено — сообщи:** "БЛОКЕР: [описание]. DEV-3 не может начать работу."

# Рабочая директория

`Test/Develop/backend/`

# Контекст существующего кода

## Config

```python
# app/config.py — УЖЕ СУЩЕСТВУЕТ:
ENCRYPTION_KEY: str = "dev-encryption-key-change-me-32b"
```

## Модель BrokerAccount (уже в БД)

```python
# Поля для шифрования:
encrypted_api_key: Mapped[bytes | None]    # LargeBinary — зашифрованный API-ключ
encrypted_api_secret: Mapped[bytes | None]  # LargeBinary — зашифрованный API-секрет
encryption_iv: Mapped[bytes | None]         # LargeBinary — IV для дешифрования
```

**Замечание:** сейчас модель имеет один `encryption_iv` для обоих зашифрованных полей. Это значит, что для каждой записи BrokerAccount мы храним один IV. Разработай подход, совместимый с этой схемой (например, derive sub-IVs или храни IV+ciphertext в одном поле). Если считаешь это небезопасным — реализуй безопасный вариант и опиши его в комментарии для ARCH-ревью.

# Задачи

## 1. CryptoService (`app/common/crypto.py`)

Замени стаб полной реализацией:

```python
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes

class CryptoService:
    """AES-256-GCM шифрование для API-ключей брокера."""

    IV_SIZE = 12  # 96 бит — рекомендация NIST для GCM
    KEY_SIZE = 32  # 256 бит

    def __init__(self, master_key: str):
        """
        Args:
            master_key: Мастер-ключ из конфига (ENCRYPTION_KEY).
                        Из него деривируется фактический AES-ключ через HKDF.
        """
        self._aes_key = self._derive_key(master_key)

    def _derive_key(self, master_key: str) -> bytes:
        """Деривация AES-256 ключа из мастер-ключа через HKDF-SHA256."""
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=self.KEY_SIZE,
            salt=None,  # Salt можно добавить позже для дополнительной безопасности
            info=b"moex-terminal-broker-keys",
        )
        return hkdf.derive(master_key.encode("utf-8"))

    def encrypt(self, plaintext: str) -> tuple[bytes, bytes]:
        """Зашифровать строку.

        Returns:
            (ciphertext, iv) — ciphertext включает GCM-тег (16 байт в конце)
        """
        iv = os.urandom(self.IV_SIZE)
        aesgcm = AESGCM(self._aes_key)
        ciphertext = aesgcm.encrypt(iv, plaintext.encode("utf-8"), None)
        return ciphertext, iv

    def decrypt(self, ciphertext: bytes, iv: bytes) -> str:
        """Дешифровать строку.

        Args:
            ciphertext: Зашифрованные данные (включая GCM-тег)
            iv: Вектор инициализации

        Returns:
            Дешифрованная строка

        Raises:
            cryptography.exceptions.InvalidTag: Если данные повреждены или ключ неверный
        """
        aesgcm = AESGCM(self._aes_key)
        plaintext = aesgcm.decrypt(iv, ciphertext, None)
        return plaintext.decode("utf-8")
```

## 2. Хелперы для брокерских ключей (`app/broker/crypto_helpers.py`)

Создай новый файл:

```python
from app.common.crypto import CryptoService
from app.config import settings

# Singleton — один экземпляр на приложение
_crypto_service: CryptoService | None = None

def get_crypto_service() -> CryptoService:
    global _crypto_service
    if _crypto_service is None:
        _crypto_service = CryptoService(settings.ENCRYPTION_KEY)
    return _crypto_service

def encrypt_broker_key(api_key: str) -> tuple[bytes, bytes]:
    """Зашифровать API-ключ брокера.

    Returns:
        (encrypted_key, iv)
    """
    return get_crypto_service().encrypt(api_key)

def decrypt_broker_key(encrypted_key: bytes, iv: bytes) -> str:
    """Дешифровать API-ключ брокера."""
    return get_crypto_service().decrypt(encrypted_key, iv)

def encrypt_broker_credentials(
    api_key: str, api_secret: str | None = None
) -> tuple[bytes, bytes | None, bytes]:
    """Зашифровать пару ключей брокера.

    Подход: используем один IV для api_key, для api_secret деривируем
    sub-IV через XOR с константой (безопасно, т.к. каждый BrokerAccount
    имеет уникальный IV).

    Returns:
        (encrypted_key, encrypted_secret, iv)
    """
    crypto = get_crypto_service()
    encrypted_key, iv = crypto.encrypt(api_key)

    encrypted_secret = None
    if api_secret:
        # Деривируем sub-IV для секрета через XOR с маркером
        secret_iv = bytes(b ^ 0x01 for b in iv)
        aesgcm = AESGCM(crypto._aes_key)
        encrypted_secret = aesgcm.encrypt(secret_iv, api_secret.encode("utf-8"), None)

    return encrypted_key, encrypted_secret, iv

def decrypt_broker_credentials(
    encrypted_key: bytes, encrypted_secret: bytes | None, iv: bytes
) -> tuple[str, str | None]:
    """Дешифровать пару ключей.

    Returns:
        (api_key, api_secret)
    """
    crypto = get_crypto_service()
    api_key = crypto.decrypt(encrypted_key, iv)

    api_secret = None
    if encrypted_secret:
        secret_iv = bytes(b ^ 0x01 for b in iv)
        aesgcm = AESGCM(crypto._aes_key)
        api_secret = aesgcm.decrypt(secret_iv, encrypted_secret, None).decode("utf-8")

    return api_key, api_secret
```

## 3. Тесты

Создай `tests/unit/test_crypto.py`:

```python
# Тесты CryptoService:
# - test_encrypt_decrypt_roundtrip — зашифровать → дешифровать → исходный текст
# - test_different_plaintexts_different_ciphertext — разные строки → разные шифротексты
# - test_same_plaintext_different_ciphertext — одна строка дважды → разные шифротексты (разный IV)
# - test_iv_is_12_bytes — проверить длину IV
# - test_wrong_key_fails — CryptoService с другим ключом → InvalidTag
# - test_corrupted_ciphertext_fails — изменить байт → InvalidTag
# - test_empty_string_encryption — пустая строка шифруется/дешифруется
# - test_special_characters — спецсимволы в API-ключе (=, +, /, пробелы)
# - test_long_api_key — длинный ключ (100+ символов)
```

Создай `tests/unit/test_crypto_helpers.py`:

```python
# Тесты хелперов:
# - test_encrypt_decrypt_broker_key_roundtrip
# - test_encrypt_decrypt_credentials_with_secret
# - test_encrypt_decrypt_credentials_without_secret
# - test_key_and_secret_have_different_ciphertext — даже если key == secret
```

**Запусти тесты:**
```bash
cd backend && pip install -e .[dev] && pytest tests/ -v
```

# Конвенции

- **НИКОГДА** не логировать plaintext API-ключи
- **НИКОГДА** не хардкодить ключи шифрования в коде
- Используй `os.urandom()` для генерации IV (криптографически безопасный)
- Все ошибки дешифрования → пробрасывай наверх (не глуши)

# Критерий завершения

- `CryptoService` с AES-256-GCM шифрованием
- HKDF деривация ключа из мастер-ключа
- Хелперы для шифрования пар ключей брокера
- **Все тесты проходят: `pytest tests/ -v` — 0 failures**
- **~8-10 новых тестов**
