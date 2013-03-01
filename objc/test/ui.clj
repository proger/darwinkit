(import '(java.awt Component))
(import '(javax.swing JFrame JButton JOptionPane JTextArea BoxLayout)) 
(import '(java.awt.event ActionListener))

(let [frame (JFrame. "Hello Swing")
     layout (BoxLayout. (.. frame getContentPane) BoxLayout/Y_AXIS)
     textfield (JTextArea. (slurp "ui.clj"))
     button (JButton. "Click Me")]

 (.addActionListener button
   (proxy [ActionListener] []
     (actionPerformed [evt]
       (JOptionPane/showMessageDialog  nil,
          (str "<html>Hello from <b>Clojure</b>b>. Button "
               (.getActionCommand evt) " clicked.")))))

 (.setEditable textfield false)
 (.setAlignmentX button Component/CENTER_ALIGNMENT)
 (doto (.getContentPane frame)
    (.setLayout layout)
    (.add textfield)
    (.add button))

 (doto frame
   (.setDefaultCloseOperation JFrame/EXIT_ON_CLOSE)
   .pack
   (.setVisible true)))
