document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');

    // START: Add this new block of code for the eye icon
    const passwordInput = document.getElementById('password');
    const togglePassword = document.getElementById('toggle-password');

    togglePassword.addEventListener('click', () => {
        // Toggle the type attribute
        const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        passwordInput.setAttribute('type', type);

        // Toggle the eye icon
        togglePassword.textContent = type === 'password' ? '👁️' : '🙈';
    });
    // END: New block of code

    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        errorMessage.textContent = '';

        const username = document.getElementById('username').value;
        const password = passwordInput.value; // Use the variable we already have

        try {
            // This URL should be relative for the CI/CD pipeline
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