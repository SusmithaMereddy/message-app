document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');

    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        errorMessage.textContent = '';

        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;

        try {
            //const response = await fetch('http://message-app-backend.internal.ambitiousground-a3ae7b53.centralindia.azurecontainerapps.io/api/login', {
            // // //const response = await fetch('http://172.29.73.220:8081/api/login', {
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