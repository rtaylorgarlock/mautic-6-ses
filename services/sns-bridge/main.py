import json
import logging
import os
from typing import Any, Dict, List, Optional

import requests
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from requests.auth import HTTPBasicAuth
import validate_aws_sns_message

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("sns-bridge")

app = FastAPI(title="SNS → Mautic Bridge", version="0.1.0")

MAUTIC_BASE_URL = os.getenv("MAUTIC_BASE_URL", "").rstrip("/")
MAUTIC_API_USERNAME = os.getenv("MAUTIC_API_USERNAME", "")
MAUTIC_API_PASSWORD = os.getenv("MAUTIC_API_PASSWORD", "")
CREATE_CONTACT_IF_MISSING = os.getenv("CREATE_CONTACT_IF_MISSING", "false").lower() in {"1", "true", "yes"}
SNS_TOPIC_ARNS = {arn.strip() for arn in os.getenv("SNS_TOPIC_ARNS", "").split(",") if arn.strip()}

SESSION = requests.Session()


def _mautic_get(path: str, params: Optional[Dict[str, Any]] = None) -> requests.Response:
    if not MAUTIC_BASE_URL:
        raise RuntimeError("MAUTIC_BASE_URL is not configured")
    url = f"{MAUTIC_BASE_URL}/api{path}"
    resp = SESSION.get(url, params=params, auth=HTTPBasicAuth(MAUTIC_API_USERNAME, MAUTIC_API_PASSWORD), timeout=10)
    return resp


def _mautic_post(path: str, data: Optional[Dict[str, Any]] = None) -> requests.Response:
    if not MAUTIC_BASE_URL:
        raise RuntimeError("MAUTIC_BASE_URL is not configured")
    url = f"{MAUTIC_BASE_URL}/api{path}"
    resp = SESSION.post(url, data=data or {}, auth=HTTPBasicAuth(MAUTIC_API_USERNAME, MAUTIC_API_PASSWORD), timeout=10)
    return resp


def find_contact_ids_by_email(email: str) -> List[int]:
    # Try advanced filtering for exact match
    params = {
        "where[0][col]": "email",
        "where[0][expr]": "eq",
        "where[0][val]": email,
    }
    r = _mautic_get("/contacts", params=params)
    if r.status_code != 200:
        logger.warning("List contacts failed (status %s): %s", r.status_code, r.text)
        return []
    data = r.json()
    contacts = data.get("contacts") or {}
    ids = [int(cid) for cid in contacts.keys()] if isinstance(contacts, dict) else []

    # Fallback to search if no results
    if not ids:
        r = _mautic_get("/contacts", params={"search": f"email:equals:{email}"})
        if r.status_code == 200:
            data = r.json()
            contacts = data.get("contacts") or {}
            ids = [int(cid) for cid in contacts.keys()] if isinstance(contacts, dict) else []
    return ids


def create_contact(email: str) -> Optional[int]:
    payload = {"email": email}
    r = _mautic_post("/contacts/new", data=payload)
    if r.status_code in (200, 201):
        try:
            data = r.json()
            # API returns {contact: {...}} or similar
            contact = data.get("contact") or (data.get("contacts") or {}).get("0")
            if contact and "id" in contact:
                return int(contact["id"])
        except Exception:  # noqa: BLE001
            logger.exception("Failed parsing create_contact response")
    else:
        logger.warning("Create contact failed (%s): %s", r.status_code, r.text)
    return None


def add_dnc(contact_id: int, reason: int, comments: str = "", channel_id: Optional[str] = None) -> bool:
    payload: Dict[str, Any] = {
        "reason": reason,
        "comments": comments,
    }
    if channel_id:
        payload["channelId"] = channel_id
    r = _mautic_post(f"/contacts/{contact_id}/dnc/email/add", data=payload)
    if r.status_code in (200, 201):
        return True
    # If already DNC, Mautic may still return 200. If not, log and continue.
    logger.warning("DNC add failed for id=%s (%s): %s", contact_id, r.status_code, r.text)
    return False


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.post("/sns/notify")
async def sns_notify(request: Request, x_amz_sns_message_type: Optional[str] = Header(default=None)):
    try:
        body_bytes = await request.body()
        message: Dict[str, Any] = json.loads(body_bytes.decode("utf-8"))
    except Exception:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    # Validate SNS signature
    try:
        validate_aws_sns_message.validate(message)
    except validate_aws_sns_message.ValidationError as e:  # type: ignore[attr-defined]
        logger.warning("SNS validation failed: %s", e)
        raise HTTPException(status_code=400, detail="Invalid SNS signature")

    topic_arn = message.get("TopicArn")
    if SNS_TOPIC_ARNS and topic_arn not in SNS_TOPIC_ARNS:
        logger.warning("SNS TopicArn not allowed: %s", topic_arn)
        raise HTTPException(status_code=403, detail="Forbidden topic")

    msg_type = message.get("Type") or x_amz_sns_message_type

    if msg_type == "SubscriptionConfirmation":
        subscribe_url = message.get("SubscribeURL")
        if not subscribe_url:
            raise HTTPException(status_code=400, detail="Missing SubscribeURL")
        try:
            resp = SESSION.get(subscribe_url, timeout=10)
            logger.info("Confirmed SNS subscription (%s) -> %s", topic_arn, resp.status_code)
        except Exception:  # noqa: BLE001
            logger.exception("Failed to confirm SNS subscription")
            raise HTTPException(status_code=500, detail="Failed to confirm subscription")
        return JSONResponse({"ok": True, "action": "subscribed"})

    if msg_type != "Notification":
        logger.info("Ignoring SNS message type %s", msg_type)
        return JSONResponse({"ok": True, "ignored": msg_type})

    # Parse SES notification JSON in Message field
    try:
        inner = json.loads(message.get("Message", "{}"))
    except Exception:  # noqa: BLE001
        logger.exception("Invalid SNS Message JSON")
        raise HTTPException(status_code=400, detail="Invalid SNS Message JSON")

    notif_type = inner.get("notificationType")
    mail = inner.get("mail", {})
    ses_message_id = mail.get("messageId")

    emails: List[str] = []
    reason = 3  # default manual
    comments = ""

    if notif_type == "Bounce":
        b = inner.get("bounce", {})
        emails = [r.get("emailAddress") for r in b.get("bouncedRecipients", []) if r.get("emailAddress")]
        bounce_type = b.get("bounceType")
        # Use BOOUNCED (2) for bounces; include type detail
        reason = 2
        comments = f"SES bounce: {bounce_type}"
    elif notif_type == "Complaint":
        c = inner.get("complaint", {})
        emails = [r.get("emailAddress") for r in c.get("complainedRecipients", []) if r.get("emailAddress")]
        # For complaints, mark as UNSUBSCRIBED (1)
        reason = 1
        comments = "SES complaint"
    else:
        logger.info("Unsupported SES notificationType: %s", notif_type)
        return JSONResponse({"ok": True, "ignored": notif_type})

    if not emails:
        logger.info("No recipient emails found in notification")
        return JSONResponse({"ok": True, "processed": 0})

    processed = 0
    for email in emails:
        try:
            ids = find_contact_ids_by_email(email)
            if not ids and CREATE_CONTACT_IF_MISSING:
                cid = create_contact(email)
                if cid:
                    ids = [cid]
            for cid in ids:
                if add_dnc(cid, reason=reason, comments=comments, channel_id=ses_message_id):
                    processed += 1
        except Exception:  # noqa: BLE001
            logger.exception("Failed processing email %s", email)

    return JSONResponse({"ok": True, "processed": processed})
