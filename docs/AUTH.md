Admin Signup (one-time): requires a setup code (provided by developer) to prevent unauthorized admin creation.

Login: email + password for all users.

Sign out.

Password reset (email link).

Profile bootstrap: on admin signup, create users/{uid} with role = admin.

Auth state stream drives navigation to Dashboard if logged in, else Login.

Validation: email format; password min 6 chars.

Error handling: show friendly messages for invalid credentials, network errors, disabled user.

Screens & UX
Login Screen

Fields: email, password.

Actions: Login, Forgot Password, Admin? Create account.

States: loading spinner on submit; inline error text.

Success → Navigate to Dashboard.

Keyboard: submit on “done”; password obscured.

Admin Signup Screen

Fields: fullName, email, password, setupCode.

Validation: required; password ≥ 6; setupCode must match.

On success:

Create Auth user

Update displayName

Create users/{uid} with role admin, status active

Navigate back to Login (or auto-login → Dashboard)

Forgot Password (lightweight)

Field: email; Action: Send reset link.

On success: toast/snackbar.

Workflows
First Admin Signup

Open Admin Signup

Enter details + setup code

Create Auth user

Write Firestore profile (role=admin)

Login → Dashboard

Login (all roles)

Email + password

On success, fetch users/{uid}

Route to Dashboard (role-aware UI)

On sign out → back to Login

Security (Summary)

Auth required for reading any profile other than self.

Only Admin can set or change role (enforced in future User Mgmt phase).

Rate-limit signup attempts (future: via Firebase rules + Functions).

Lock out suspended users (check status before granting UI access).

Firestore Rules (Stub)

Allow read/write to own users/{uid} (profile updates limited to non-role fields).

Allow admin to read all users.

Disallow non-admin from writing role or status.

Test Checklist

Valid/invalid email/password

Wrong password → inline error

Suspended user → blocked with message

Admin signup with wrong setup code → blocked

Lost network → retry UI works

