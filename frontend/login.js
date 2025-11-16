document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');
    
    // --- Eye Icon Logic ---
    const passwordInput = document.getElementById('password');
    const togglePasswordBtn = document.getElementById('toggle-password');
    const eyeOpenIcon = document.getElementById('eye-open');
    const eyeClosedIcon = document.getElementById('eye-closed');

    togglePasswordBtn.addEventListener('click', () => {
        const isPassword = passwordInput.getAttribute('type') === 'password';
        if (isPassword) {
            passwordInput.setAttribute('type', 'text');
            eyeOpenIcon.style.display = 'none';
            eyeClosedIcon.style.display = 'block';
        } else {
            passwordInput.setAttribute('type', 'password');
            eyeOpenIcon.style.display = 'block';
            eyeClosedIcon.style.display = 'none';
        }
    });

    // --- Form Submission Logic ---
    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        errorMessage.textContent = '';

        // THIS IS THE CORRECTED PART: Get values directly from the form fields by ID
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;

        try {
            const response = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });

            if (response.ok) {
                sessionStorage.setItem('authenticated', 'true');
                window.location.href = 'index.html';
            } else {
                errorMessage.textContent = 'Invalid username or password.';
            }
        } catch (error) {
            console.error('Login error:', error);
            errorMessage.textContent = 'An error occurred. Please try again.';
        }
    });
});