import React, { useState } from 'react';
import SignIn from './SignIn/SignIn';
import SignUp from './SignUp/SignUp';

export default function AuthFormSwitcher() {
    const [showLogin, setShowLogin] = useState(true);

    const handleSwitch = () => {
        setShowLogin(!showLogin);
    };

    return (
        <div>
            {showLogin ? (
                <SignIn switchToSignup={handleSwitch} />
            ) : (
                <SignUp switchToLogin={handleSwitch} />
            )}
        </div>
    );
}