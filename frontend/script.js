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

    // 🔹 Format timestamp as local time dd:MM:yyyy HH:mm:ss
    function formatTimestamp(isoString) {
        if (!isoString) return '';

        const date = new Date(isoString); // converts UTC → local time in browser

        const pad = (n) => n.toString().padStart(2, '0');

        const day = pad(date.getDate());
        const month = pad(date.getMonth() + 1); // months start at 0
        const year = date.getFullYear();

        const hours = pad(date.getHours());
        const minutes = pad(date.getMinutes());
        const seconds = pad(date.getSeconds());

        return `${day}:${month}:${year} ${hours}:${minutes}:${seconds}`;
    }

    // Send message
    sendBtn.addEventListener('click', async () => {
        const content = messageInput.value.trim();
        if (!content) {
            alert('Message cannot be empty.');
            return;
        }

        try {
            const response = await fetch('/api/messages', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ content: content })
            });

            if (response.ok) {
                messageInput.value = '';
                charCounter.textContent = '0 / 250';
                alert('Message sent successfully!');
                // Optionally reload messages:
                // await retrieveMessages();
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
            if (!response.ok) {
                console.error('Failed to fetch messages, status:', response.status);
                return;
            }

            const messages = await response.json();

            messageTableBody.innerHTML = ''; // Clear existing table
            messages.forEach(msg => {
                const formatted = formatTimestamp(msg.timestamp);
                console.log('DEBUG timestamp:', msg.timestamp, '=>', formatted);

                const row = `<tr>
                                <td>${msg.content}</td>
                                <td>${formatted}</td>
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
