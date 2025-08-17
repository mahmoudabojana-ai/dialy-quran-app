import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { getFirestore, collection, addDoc, query, orderBy, onSnapshot, doc, deleteDoc } from 'firebase/firestore';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithCustomToken, signInAnonymously, onAuthStateChanged } from 'firebase/auth';

// Global variables from the Canvas environment
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
const initialAuthToken = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;

// Reusable TailwindCSS class strings for components
const buttonClasses = "px-4 py-2 bg-teal-600 text-white font-semibold rounded-lg shadow-md hover:bg-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-500 focus:ring-offset-2 transition-colors";
const inputClasses = "flex-1 w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:border-teal-500 transition-colors text-right";
const cardClasses = "w-full max-w-md bg-white rounded-2xl shadow-xl p-6";

// SVG icons for a single-file app
const BookOpenIcon = (props) => (
  <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
    <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
  </svg>
);
const Loader2Icon = (props) => (
  <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 12a9 9 0 1 1-6.219-8.56" />
  </svg>
);
const Trash2Icon = (props) => (
  <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M3 6h18" />
    <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
    <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
    <line x1="10" x2="10" y1="11" y2="17" />
    <line x1="14" x2="14" y1="11" y2="17" />
  </svg>
);

// The main App component for the Daily Quran Tracker
export default function App() {
  const [readings, setReadings] = useState([]);
  const [pagesInput, setPagesInput] = useState("");
  const [db, setDb] = useState(null);
  const [userId, setUserId] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAdding, setIsAdding] = useState(false);
  const [totalPages, setTotalPages] = useState(0);

  // Initialize Firebase and Auth on mount
  useEffect(() => {
    try {
      const app = initializeApp(firebaseConfig);
      const auth = getAuth(app);
      const firestore = getFirestore(app);
      setDb(firestore);

      const unsubscribe = onAuthStateChanged(auth, async (user) => {
        if (user) {
          setUserId(user.uid);
          setIsLoading(false);
        } else {
          try {
            if (initialAuthToken) {
              await signInWithCustomToken(auth, initialAuthToken);
            } else {
              await signInAnonymously(auth);
            }
          } catch (error) {
            console.error("Error signing in:", error);
            setIsLoading(false);
          }
        }
      });
      return () => unsubscribe();
    } catch (e) {
      console.error("Firebase initialization failed", e);
      setIsLoading(false);
    }
  }, []);

  // Set up real-time listener for readings and calculate total pages
  useEffect(() => {
    if (db && userId) {
      const collectionPath = `artifacts/${appId}/users/${userId}/dailyQuranReadings`;
      // Firestore queries with orderBy need an index to function correctly.
      // To avoid this, we fetch all and sort client-side, which is a better practice in this environment.
      const q = query(collection(db, collectionPath));
      const unsubscribe = onSnapshot(q, (querySnapshot) => {
        let pagesCount = 0;
        const readingsData = [];
        querySnapshot.forEach((doc) => {
          const data = doc.data();
          pagesCount += data.pages;
          readingsData.push({ id: doc.id, ...data });
        });
        // Sort the data after fetching it
        readingsData.sort((a, b) => b.date - a.date);
        setReadings(readingsData);
        setTotalPages(pagesCount);
        setIsLoading(false);
      }, (error) => {
        console.error("Failed to fetch readings:", error);
        setIsLoading(false);
      });
      return () => unsubscribe();
    }
  }, [db, userId]);

  // Function to add a new reading entry
  const addReading = async () => {
    const pages = parseInt(pagesInput, 10);
    if (!isNaN(pages) && pages > 0 && db && userId && !isAdding) {
      setIsAdding(true);
      try {
        const collectionPath = `artifacts/${appId}/users/${userId}/dailyQuranReadings`;
        await addDoc(collection(db, collectionPath), {
          pages: pages,
          date: Date.now(),
        });
        setPagesInput("");
      } catch (e) {
        console.error("Error adding document: ", e);
      } finally {
        setIsAdding(false);
      }
    }
  };

  // Function to delete a reading entry
  const deleteReading = async (id) => {
    if (db && userId) {
      try {
        const docPath = `artifacts/${appId}/users/${userId}/dailyQuranReadings/${id}`;
        await deleteDoc(doc(db, docPath));
      } catch (e) {
        console.error("Error deleting document: ", e);
      }
    }
  };

  const getTodayReadings = () => {
    const today = new Date().toLocaleDateString("en-US");
    return readings
      .filter(r => new Date(r.date).toLocaleDateString("en-US") === today)
      .reduce((sum, r) => sum + r.pages, 0);
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-teal-100 to-white p-6 flex flex-col items-center font-sans">
      <motion.h1
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-4xl font-extrabold text-teal-800 mb-6 text-center"
      >
        📖 قارئ الورد اليومي
      </motion.h1>

      <div className={cardClasses}>
        <div className="p-0">
          <div className="flex gap-2 mb-4">
            <input
              type="number"
              placeholder="عدد الصفحات التي قرأتها اليوم"
              value={pagesInput}
              onChange={(e) => setPagesInput(e.target.value)}
              className={inputClasses}
              dir="rtl"
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  addReading();
                }
              }}
            />
            <button
              onClick={addReading}
              className={`${buttonClasses}`}
              disabled={isAdding}
            >
              {isAdding ? <Loader2Icon className="h-4 w-4 animate-spin" /> : "إضافة"}
            </button>
          </div>

          <div className="space-y-4 max-h-80 overflow-y-auto pr-2">
            {isLoading ? (
              <div className="flex justify-center items-center h-40">
                <Loader2Icon className="h-8 w-8 animate-spin text-teal-500" />
              </div>
            ) : readings.length === 0 ? (
              <p className="text-gray-500 text-center mt-10">ابدأ بتسجيل أول ورد لك! 🕌</p>
            ) : (
              readings.map((reading) => (
                <motion.div
                  key={reading.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="p-4 bg-teal-50 rounded-lg shadow-sm flex items-center justify-between"
                >
                  <div className="flex-1">
                    <p className="text-teal-800 font-medium">
                      {reading.pages} صفحة
                    </p>
                    <span className="text-xs text-gray-400">
                      {new Date(reading.date).toLocaleDateString("ar-EG", {
                        day: "numeric",
                        month: "long",
                        year: "numeric",
                      })}
                    </span>
                  </div>
                  <button
                    onClick={() => deleteReading(reading.id)}
                    className="p-1 rounded-full text-gray-400 hover:text-red-500 transition-colors"
                  >
                    <Trash2Icon className="h-4 w-4" />
                  </button>
                </motion.div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="mt-8 text-center">
        <div className="bg-white p-6 rounded-2xl shadow-lg w-full max-w-md">
          <h2 className="text-lg font-semibold text-teal-800">إحصائيات القراءة</h2>
          <div className="mt-4 space-y-2">
            <div className="flex justify-between items-center text-gray-700">
              <span className="font-medium">صفحات اليوم:</span>
              <span className="font-bold text-xl text-teal-600">{getTodayReadings()}</span>
            </div>
            <div className="flex justify-between items-center text-gray-700">
              <span className="font-medium">الإجمالي الكلي:</span>
              <span className="font-bold text-xl text-teal-600">{totalPages}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
