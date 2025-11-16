document.addEventListener('DOMContentLoaded', () => {
    // Redirect to login if not authenticated
    if (!sessionStorage.getItem('authenticated')) {
        window.location.href = 'login.html';
        return; // Stop script execution
    }

    const messageInput = document.getElementById('message-input');
    const charCounter = document.getElementById('char-counter');
    const sendBtn = document.getElementById('send-btn');
    const retrieveBtn = document.getElementById('retrieve-btn');
    const messageTableBody = document.querySelector('#message-table tbody');
    const logoutBtn = document.getElementById('logout-btn');

    // Character counter
    messageInput.addEventListener('input', () => {
        const count = messageInput.value.length;
        charCounter.textContent = `${count} / 250`;
    });
    // send message
    sendBtn.addEventListener('click', async () => {
        const content = messageInput.value.trim();
        if (!content) {
            alert('Message cannot be empty.');
            return;
        }

        try {
            //const response = await fetch(`http://message-app-backend.internal.ambitiousground-a3ae7b53.centralindia.azurecontainerapps.io/api/messages`, {
            // //    // const response = await fetch(`http://172.29.73.220:8081/api/messages`, {
            const response = await fetch('/api/messages', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ content: content })
            });

            if (response.ok) {
                messageInput.value = '';
                charCounter.textContent = '0 / 250';
                alert('Message sent successfully!');
                // The automatic retrieveMessages() call has been removed.
            } else {
                alert('Failed to send message.');
            }
        } catch (error) {
            console.error('Error sending message:', error);
            alert('An error occurred.');
        }
    });
    // Retrieve messages
    const retrieveMessages = async () => {
        try {
            const response = await fetch('/api/messages');
            const messages = await response.json();

            messageTableBody.innerHTML = ''; // Clear existing table
            messages.forEach(msg => {
                const row = `<tr>
                                <td>${msg.content}</td>
                                <td>${msg.timestamp}</td>
                             </tr>`;
                messageTableBody.innerHTML += row;
            });
        } catch (error) {
            console.error('Error retrieving messages:', error);
        }
    };

    retrieveBtn.addEventListener('click', retrieveMessages);

    // Logout
    logoutBtn.addEventListener('click', () => {
        sessionStorage.removeItem('authenticated');
        window.location.href = 'login.html';
    });

    // Initial load
    retrieveMessages();
});