document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');
    const passwordInput = document.getElementById('password');
    const togglePasswordBtn = document.getElementById('toggle-password');
    const eyeOpenIcon = document.getElementById('eye-open');
    const eyeClosedIcon = document.getElementById('eye-closed');

    // Event listener for the icon button
    togglePasswordBtn.addEventListener('click', () => {
        const isPassword = passwordInput.getAttribute('type') === 'password';

        if (isPassword) {
            // Change to text (show password)
            passwordInput.setAttribute('type', 'text');
            // Show the closed eye icon
            eyeOpenIcon.style.display = 'none';
            eyeClosedIcon.style.display = 'block';
        } else {
            // Change back to password (hide password)
            passwordInput.setAttribute('type', 'password');
            // Show the open eye icon
            eyeOpenIcon.style.display = 'block';
            eyeClosedIcon.style.display = 'none';
        }
    });

    // Event listener for the form submission
    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        errorMessage.textContent = '';

        const username = document.getElementById('username').value;
        const password = passwordInput.value;

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