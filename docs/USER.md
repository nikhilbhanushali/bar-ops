# USER — User Profile Documentation

## Purpose
This document describes the structure and fields for a single user profile in the BarOps system.

## Collection: users/{uid}
```json
{
  "displayName": "Jane Admin",
  "email": "jane@barops.test",
  "phone": "",
  "role": "admin|store|designer|engineer|accounts",
  "status": "active|suspended",
  "createdAt": "ISO",
  "createdBy": "{uid}",
  "updatedAt": "ISO",
  "updatedBy": "{uid}"
}
```

## Field Descriptions
- **displayName**: Full name of the user.
- **email**: User's email address.
- **phone**: User's phone number (optional).
- **role**: User's role in the system. One of: admin, store, designer, engineer, accounts.
- **status**: Account status. Either "active" or "suspended".
- **createdAt**: ISO8601 timestamp when the user was created.
- **createdBy**: UID of the admin who created the user.
- **updatedAt**: ISO8601 timestamp when the user was last updated.
- **updatedBy**: UID of the admin who last updated the user.

