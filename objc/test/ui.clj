(import '[java.awt Component])
(import '[javax.swing JFrame JButton JOptionPane JTextArea BoxLayout]) 
(import '[java.awt.event ActionListener])

(let [frame (doto (JFrame. "Hello Swing")
              (.setDefaultCloseOperation JFrame/EXIT_ON_CLOSE))
      layout (BoxLayout. (.getContentPane frame) BoxLayout/Y_AXIS)
      textfield (doto (JTextArea. (slurp "ui.clj"))
                  (.setEditable false))
      button (doto (JButton. "Click Me")
               (.setAlignmentX Component/CENTER_ALIGNMENT)
               (.addActionListener 
                 (reify ActionListener
                   (actionPerformed [this evt]
                     (JOptionPane/showMessageDialog
                       nil
                       (str
                         "<html>Hello from <b>Clojure</b>. "
                         "Button " (.getActionCommand evt) " clicked."))))))]

  (doto (.getContentPane frame)
    (.setLayout layout)
    (.add textfield)
    (.add button))

  (doto frame
    .pack
    (.setLocationRelativeTo nil)
    (.setVisible true)))
